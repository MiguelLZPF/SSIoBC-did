#!/usr/bin/env python3
"""Fail a doc that points at something which does not exist.

A 2026-08-28 documentation audit found the same defect everywhere: prose naming
a script, a manifest or a directory that had been deleted or moved years
earlier, and six commit hashes cited as evidence that no object in that
repository had ever had. None of it errors, nothing renders red, and a reader
following the pointer concludes the doc is wrong about everything else too.

Three passes over the configured scope (`link_scope_prefixes` and
`link_scope_files`):

  link   `[text](target)` -- a repo-relative target must exist. http(s),
         mailto, `~` home paths and bare `#anchors` are skipped; a `#anchor`
         suffix is stripped before the existence test (anchors themselves are
         not validated).
  path   a backticked token starting with one of the config's `path_prefixes`
         must exist. This is the pass that catches the audited class, because
         those references are prose, not links, so no renderer has ever
         checked them.
  hash   a cited commit hash must resolve. 8-12 or 40 hex characters, in
         backticks or after the word "commit", checked with
         `git cat-file --batch-check`.

CONSERVATIVE BY CONSTRUCTION. Every pass would rather miss a violation than
invent one, because a checker with false positives gets switched off and then
catches nothing at all. Skipped without comment: any token holding < > * { } $
or whitespace (templated paths, globs, command lines), anything inside a fenced
code block, hex runs of other lengths (a 32-char BLE UUID is not a short hash),
and any line carrying a `<!-- path-ignore -->` pragma. A git-crypt path is
skipped whole (gitcrypt_paths.py): all three passes read content, a CI runner
holds no key, and ciphertext yields no links worth believing. A target that
`git check-ignore` calls ignored is skipped by the link and path passes for the
same reason: a doc naming `.env` documents a deliberately untracked local
artifact, which is absent from every fresh checkout by design.

PER-REPO CONFIG. The scope and the path prefixes come from
`scripts/ci/doc-lint-config.json`, written by the installer from the repo's real
layout. The defaults below apply when that file is absent.

GRANDFATHERING. Existing violations are pinned in
`scripts/ci/doc-links-baseline.txt` (--write-baseline). Only violations absent
from it fail. Link rot happens when the TARGET moves, which a changed-files
hook cannot see, so CI runs --all weekly.

Modes:

    check-doc-links.py FILE...            # pre-commit
    check-doc-links.py --all              # whole tree (CI, weekly)
    check-doc-links.py --write-baseline
    check-doc-links.py --test             # self-test
"""
import fnmatch
import functools
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gitcrypt_paths  # noqa: E402  (sibling module, path fixed above)

BASELINE = pathlib.Path("scripts/ci/doc-links-baseline.txt")
CONFIG_FILE = pathlib.Path(os.path.dirname(os.path.abspath(__file__))) / "doc-lint-config.json"

DEFAULTS = {
    "link_scope_prefixes": ["docs/", ".claude/rules/", ".claude/skills/"],
    "link_scope_files": ["README.md", "CLAUDE.md", "PROJECT.md"],
    "path_prefixes": ["docs", "scripts", ".claude"],
    "exclude_globs": [
        "lib/**",
        "node_modules/**",
        "vendor/**",
        "third_party/**",
        "target/**",
        "out/**",
        "cache/**",
        "typechain-types/**",
        "artifacts/**",
    ],
}

MD_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
BACKTICK = re.compile(r"`([^`\n]+)`")
HEX = re.compile(r"^[0-9a-f]+$")
COMMIT_WORD = re.compile(r"\bcommits?\s+([0-9a-f]{8,40})\b")
# A bare hex run means nothing on its own. Measured against a real tree,
# dropping the context requirement produced 56 hits of which the majority were
# an IPv6 prefix (fe800000), byte counts (67108864), firewall rule UUIDs and
# media file digests -- so the token must sit within a line or two of a word
# that actually claims it is a commit. "SHA" is deliberately NOT such a word:
# it is routinely used for file digests.
COMMIT_CONTEXT = re.compile(
    r"\b(commit|commits|committed|cherry-pick|cherry-picked|revert|reverted"
    r"|git show|git log|git revert)\b",
    re.IGNORECASE,
)
FENCE = re.compile(r"^\s*(```|~~~)")

BAD_CHARS = set("<>*{}$ \t|")
# Real cited SHAs are short (8) or full (40). Everything between is ambiguous --
# a 32-hex UUID is a common false positive -- so it is skipped.
HASH_LENGTHS = frozenset({8, 9, 10, 11, 12, 40})

PRAGMA = "<!-- path-ignore -->"


def load_config() -> dict:
    """DEFAULTS overlaid with the repo's own config, if it wrote one."""
    cfg = dict(DEFAULTS)
    if CONFIG_FILE.is_file():
        try:
            cfg.update(json.loads(CONFIG_FILE.read_text()))
        except (OSError, ValueError):
            pass
    cfg["_repo_path_re"] = re.compile(
        "^(" + "|".join(re.escape(p) for p in cfg["path_prefixes"]) + ")/"
    )
    return cfg


def excluded(cfg: dict, path: str) -> bool:
    for pat in cfg["exclude_globs"]:
        if fnmatch.fnmatch(path, pat) or path.startswith(pat.rstrip("*/") + "/"):
            return True
    return False


def in_scope(cfg: dict, path: str) -> bool:
    if excluded(cfg, path):
        return False
    return path in cfg["link_scope_files"] or path.startswith(tuple(cfg["link_scope_prefixes"]))


def strip_anchor(target: str) -> str:
    return target.split("#", 1)[0]


def skippable(token: str) -> bool:
    return (not token) or any(c in BAD_CHARS for c in token)


def looks_like_hash(token: str) -> bool:
    """A short hex run that could plausibly be an abbreviated object name.

    Length is checked against HASH_LENGTHS, and both a letter and a digit are
    required: an all-decimal run is a number (a byte count, an epoch), and an
    all-letter run is a word.
    """
    if len(token) not in HASH_LENGTHS:
        return False
    return any(c.isdigit() for c in token) and any(c in "abcdef" for c in token)


def code_fence_mask(lines):
    """True for every line inside a fenced code block."""
    mask = []
    inside = False
    for line in lines:
        if FENCE.match(line):
            inside = not inside
            mask.append(True)
            continue
        mask.append(inside)
    return mask


@functools.lru_cache(maxsize=None)
def _check_ignore(root_str: str, rel: str) -> bool:
    """`git check-ignore`: 0 means ignored, 1 means not, anything else is no git.

    FAIL-OPEN, deliberately and narrowly: with no git we cannot ask, so the
    target is validated for existence exactly as before. The cost of being
    wrong here is a false accusation on a machine that has no git and therefore
    no repository either, which is not a case that occurs in CI or pre-commit.
    """
    try:
        proc = subprocess.run(
            ["git", "check-ignore", "-q", "--", rel],
            cwd=root_str,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return False
    return proc.returncode == 0


def gitignored(root: pathlib.Path, doc: pathlib.PurePosixPath, target: str) -> bool:
    """True when the target is a deliberately untracked local artifact.

    A doc naming `.claude/settings.local.json` or a `.env` is documenting
    something that exists on a developer's machine and is ignored on purpose.
    It can never resolve in a fresh CI checkout, so validating its existence
    measures the checkout rather than the doc: the same class of meaningless
    check as reading ciphertext for a ToC, and skipped for the same reason.

    The rule must live in the repo's own .gitignore to be worth anything. A
    personal ~/.config/git/ignore makes CI and the developer disagree.

    KNOWN NARROWING, recorded rather than hidden: a repo whose .gitignore has a
    broad pattern (`**/*secret*`) will have dead references matching it skipped
    instead of reported. The breadth is the ignore file's, not this check's.
    """
    for cand in (os.path.normpath(str(doc.parent / target)), os.path.normpath(target)):
        if cand.startswith("..") or cand == ".":
            continue
        if _check_ignore(str(root), cand):
            return True
    return False


def exists(root: pathlib.Path, doc: pathlib.PurePosixPath, target: str) -> bool:
    """Accept a target that resolves either beside the doc or from the repo root.

    Markdown says relative-to-the-file, but root-relative paths without a
    leading slash are written inside docs/ too, and accepting both is the
    conservative choice: a target that exists under either reading is not rot.
    """
    reads = [target]
    # A markdown link to a file whose name holds a space is written `%20`, and
    # 33 such links in one repo were reported as rot by an earlier version of
    # this check. Percent-decoding is tried IN ADDITION to the raw form, never
    # instead of it, so a filename that really contains a `%` still resolves.
    decoded = urllib.parse.unquote(target)
    if decoded != target:
        reads.append(decoded)
    candidates = [base / t for t in reads for base in (root / doc.parent, root)]
    for c in candidates:
        try:
            if c.exists():
                return True
        except OSError:
            continue
    return False


def scan(cfg: dict, root: pathlib.Path, path: str):
    """Yield (code, key, message) candidate violations for one doc."""
    full = root / path
    if not full.is_file():
        return
    text = gitcrypt_paths.readable_text(root, path, full)
    if text is None:
        # Encrypted, binary or undecodable: every pass below reads content.
        return
    lines = text.splitlines()
    fenced = code_fence_mask(lines)
    doc = pathlib.PurePosixPath(path)
    repo_path = cfg["_repo_path_re"]

    for n, line in enumerate(lines):
        if PRAGMA in line:
            continue
        in_fence = fenced[n]

        if not in_fence:
            for target in MD_LINK.findall(line):
                if target.startswith(("http://", "https://", "mailto:", "#", "~", "/")):
                    continue
                t = strip_anchor(target)
                if skippable(t):
                    continue
                if not exists(root, doc, t) and not gitignored(root, doc, t):
                    yield (
                        "link",
                        f"{path} {t}",
                        f"{path}:{n + 1}: dead link -> {t}",
                    )

        for token in BACKTICK.findall(line):
            if in_fence:
                break
            if skippable(token) or not repo_path.match(token):
                continue
            t = strip_anchor(token).rstrip(".,;:")
            if not t:
                continue
            if not exists(root, doc, t) and not gitignored(root, doc, t):
                yield (
                    "path",
                    f"{path} {t}",
                    f"{path}:{n + 1}: reference to a path that does not exist -> {t}",
                )

        if in_fence:
            continue
        window = (lines[n - 1] + " " if n else "") + line
        if not COMMIT_CONTEXT.search(window):
            continue
        for token in BACKTICK.findall(line):
            if skippable(token) or not HEX.match(token):
                continue
            if looks_like_hash(token):
                yield ("hash", f"{path} {token}", f"{path}:{n + 1}: {token}")
        for token in COMMIT_WORD.findall(line):
            if looks_like_hash(token):
                yield ("hash", f"{path} {token}", f"{path}:{n + 1}: {token}")


def resolve_hashes(root: pathlib.Path, candidates):
    """Return the subset of hashes that are NOT commits in this repository."""
    if not candidates:
        return set()
    stdin = "\n".join(f"{h}^{{commit}}" for h in sorted(candidates)) + "\n"
    proc = subprocess.run(
        ["git", "cat-file", "--batch-check"],
        cwd=root,
        input=stdin,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0 and not proc.stdout:
        # No git, no verdict. Silence beats a false accusation.
        return set()
    missing = set()
    for line in proc.stdout.splitlines():
        first = line.split(" ", 1)[0]
        if " missing" in line or line.endswith("missing"):
            missing.add(first.replace("^{commit}", ""))
    return missing


def basenames(root: pathlib.Path):
    proc = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, capture_output=True, text=True, check=False
    )
    return {pathlib.PurePosixPath(p).name for p in proc.stdout.split("\0") if p}


def run(root: pathlib.Path, targets, baseline, cfg=None):
    cfg = cfg or load_config()
    raw = []
    for path in targets:
        raw.extend(scan(cfg, root, path))

    hash_tokens = {key.split(" ", 1)[1] for code, key, _ in raw if code == "hash"}
    names = basenames(root)
    # A token that is also a real filename is a filename, not a bad hash.
    hash_tokens = {h for h in hash_tokens if h not in names and f"{h}.md" not in names}
    missing = resolve_hashes(root, hash_tokens)

    out = []
    for code, key, msg in raw:
        if code == "hash":
            token = key.split(" ", 1)[1]
            if token not in missing:
                continue
            msg = f"{msg} is cited as a commit and does not exist"
        if (code, key) in baseline:
            continue
        out.append((code, key, msg))
    return out


def read_baseline(root: pathlib.Path):
    f = root / BASELINE
    if not f.exists():
        return set()
    out = set()
    for line in f.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        code, _, key = line.partition(" ")
        out.add((code, key.strip()))
    return out


def all_docs(cfg: dict, root: pathlib.Path):
    proc = subprocess.run(
        ["git", "ls-files", "-z", "*.md"], cwd=root, capture_output=True, text=True, check=False
    )
    return sorted(p for p in proc.stdout.split("\0") if p and in_scope(cfg, p))


def staged_docs(cfg: dict, root: pathlib.Path):
    proc = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    return sorted(p for p in proc.stdout.splitlines() if p.endswith(".md") and in_scope(cfg, p))


def repo_root() -> pathlib.Path:
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False
    )
    return pathlib.Path(proc.stdout.strip()) if proc.returncode == 0 else pathlib.Path.cwd()


def write_baseline(cfg: dict, root: pathlib.Path):
    violations = run(root, all_docs(cfg, root), set(), cfg)
    lines = sorted({f"{code} {key}" for code, key, _ in violations})
    body = (
        "# Grandfathered dead links, dead paths and dead commit hashes.\n"
        "# Generated by scripts/ci/check-doc-links.py --write-baseline\n"
        "# Only violations ABSENT from this list fail. Shrinking it is the point;\n"
        "# never add a line by hand to silence a fresh break.\n"
    ) + ("\n".join(lines) + "\n" if lines else "")
    (root / BASELINE).write_text(body)
    print(f"wrote {BASELINE} with {len(lines)} entries")
    return 0


# --------------------------------------------------------------------------
# self-test
# --------------------------------------------------------------------------


def selftest() -> int:
    failures = []
    cfg = dict(DEFAULTS)
    cfg["_repo_path_re"] = re.compile(
        "^(" + "|".join(re.escape(p) for p in cfg["path_prefixes"]) + ")/"
    )

    def check(name, cond):
        if cond:
            print(f"  ok   {name}")
        else:
            print(f"  FAIL {name}")
            failures.append(name)

    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.email", "t@t"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.name", "t"], cwd=root, check=True)
        (root / "docs").mkdir()
        (root / "scripts").mkdir()
        (root / "docs" / "real.md").write_text("# real\n")
        (root / "scripts" / "real.sh").write_text("#!/bin/sh\n")
        (root / "docs" / "t.md").write_text("# t\n")
        subprocess.run(["git", "add", "-A"], cwd=root, check=True)
        subprocess.run(["git", "commit", "-qm", "seed"], cwd=root, check=True)
        real_hash = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True
        ).stdout.strip()

        def doc(body):
            (root / "docs" / "t.md").write_text(body)
            return run(root, ["docs/t.md"], set(), cfg)

        v = doc("See [x](missing-file.md)\n")
        check("dead link fails", any(c == "link" for c, _, _ in v))

        v = doc("See [x](real.md) and [y](../scripts/real.sh)\n")
        check("valid links pass", not v)

        v = doc("See [x](https://example.com) and [y](#anchor)\n")
        check("http and anchor skipped", not v)

        v = doc("See [x](real.md#a-section)\n")
        check("anchor suffix stripped", not v)

        (root / "docs" / "a real file.md").write_text("# spaced\n")
        v = doc("See [x](a%20real%20file.md)\n")
        check("percent-encoded link resolves", not v)
        v = doc("See [x](a%20missing%20file.md)\n")
        check("percent-encoded link to nothing still fails", any(c == "link" for c, _, _ in v))

        v = doc("Run `scripts/gone.sh` now\n")
        check("dead backticked path fails", any(c == "path" for c, _, _ in v))

        v = doc("Run `scripts/real.sh` now\n")
        check("live backticked path passes", not v)

        v = doc("Run `scripts/*.sh` and `docs/${x}/y.md`\n")
        check("glob and template skipped", not v)

        v = doc("Run `scripts/gone.sh` now " + PRAGMA + "\n")
        check("path-ignore pragma skipped", not v)

        v = doc("Fixed in commit `deadbeef1234`\n")
        check("fake hash fails", any(c == "hash" for c, _, _ in v))

        v = doc(f"Fixed in commit `{real_hash}`\n")
        check("real full hash passes", not v)

        v = doc(f"Fixed in commit {real_hash[:8]}\n")
        check("real short hash after 'commit' passes", not v)

        v = doc("Reverted in\nthe commit `deadbeef1234`\n")
        check("commit context found on the previous line", any(c == "hash" for c, _, _ in v))

        v = doc("Controller `deadbeef1234` maps the upper bank\n")
        check("hex with no commit context skipped", not v)

        v = doc("Beacon `fda50693a4e24fb1afcfc6eb07647825` in commit terms\n")
        check("32-hex UUID not read as a hash", not v)

        v = doc("The commit moved `137438953472` bytes\n")
        check("all-decimal run not read as a hash", not v)

        v = doc("```\ncommit `deadbeef1234`\n`scripts/gone.sh`\n```\n")
        check("fenced block skipped", not v)

        v = doc("Fixed in commit `deadbeef1234`\n")
        v2 = run(root, ["docs/t.md"], {("hash", "docs/t.md deadbeef1234")}, cfg)
        check("baselined hash passes", v and not v2)

        # scope and exclusions are the config's decision, not the code's
        check("in_scope honours the config", in_scope(cfg, "docs/t.md"))
        check("out-of-scope path ignored", not in_scope(cfg, "src/notes.md"))
        check("vendored path excluded from scope", not in_scope(cfg, "lib/forge-std/docs/x.md"))

        # git-crypt: every pass here reads content, so the whole doc is skipped.
        rot = "See [x](missing-file.md), run `scripts/gone.sh`, commit `deadbeef1234`\n"

        (root / "docs" / "crypt.md").write_text(rot)
        v = run(root, ["docs/crypt.md"], set(), cfg)
        check("control: the fixture IS rotten before encryption", len(v) == 3)

        (root / "docs" / ".gitattributes").write_text("crypt.md filter=git-crypt\n")
        gitcrypt_paths.reset_cache()
        v = run(root, ["docs/crypt.md"], set(), cfg)
        check("git-crypt path: no content check runs", not v)

        # and a neighbour in the same directory is untouched by that rule
        (root / "docs" / "plain.md").write_text(rot)
        v = run(root, ["docs/plain.md"], set(), cfg)
        check("non-git-crypt neighbour still judged", len(v) == 3)

        # magic bytes alone are enough, with no .gitattributes rule for it
        (root / "docs" / "locked.md").write_bytes(
            gitcrypt_paths.GITCRYPT_MAGIC + b"\x00\x01" + rot.encode()
        )
        v = run(root, ["docs/locked.md"], set(), cfg)
        check("ciphertext without an attribute rule: not judged", not v)

        # Gitignored targets. ONE variable moves between the control and the
        # case: whether .gitignore names the target. The file is absent in both,
        # which is the condition that matters -- a fresh CI checkout is exactly
        # "ignored artifacts are not here". Both passes are exercised, so the
        # count is 2.
        both = "Copy `docs/local-artifact.json` and see [it](local-artifact.json)\n"
        (root / "docs" / "ign.md").write_text(both)

        (root / ".gitignore").write_text("unrelated.txt\n")
        _check_ignore.cache_clear()
        v = run(root, ["docs/ign.md"], set(), cfg)
        check("control: absent + NOT ignored -> link and path both fail", len(v) == 2)

        (root / ".gitignore").write_text("unrelated.txt\ndocs/local-artifact.json\n")
        _check_ignore.cache_clear()
        v = run(root, ["docs/ign.md"], set(), cfg)
        check("absent + ignored -> both passes skip it", not v)

        # A gitignored target that IS present passes too. This one cannot fail
        # by construction (existence alone satisfies both passes), so it is a
        # guard against the skip breaking a valid reference, NOT evidence that
        # the skip works. The pair above is that evidence.
        (root / "docs" / "local-artifact.json").write_text("{}\n")
        v = run(root, ["docs/ign.md"], set(), cfg)
        check("guard: gitignored but present is still fine", not v)

    gitcrypt_paths.reset_cache()
    _check_ignore.cache_clear()
    print(f"\n{'FAILED' if failures else 'PASSED'}: {len(failures)} failing case(s)")
    return 1 if failures else 0


def main() -> int:
    argv = sys.argv[1:]
    flags = [a for a in argv if a.startswith("--")]
    files = [a for a in argv if not a.startswith("--")]

    if "--test" in flags:
        return selftest()

    root = repo_root()
    os.chdir(root)
    cfg = load_config()

    if "--write-baseline" in flags:
        return write_baseline(cfg, root)

    if "--all" in flags:
        targets = all_docs(cfg, root)
    elif files:
        targets = [f for f in files if f.endswith(".md") and in_scope(cfg, f)]
    else:
        targets = staged_docs(cfg, root)

    if not targets:
        return 0

    violations = run(root, targets, read_baseline(root), cfg)
    if not violations:
        return 0

    print("Documentation references that do not resolve:\n", file=sys.stderr)
    for _, _, msg in sorted(violations, key=lambda v: v[2]):
        print(f"  {msg}", file=sys.stderr)
    print(
        "\nFix the reference, or move the target back."
        f"\n{BASELINE} grandfathers pre-existing rot; it is not a place to"
        "\nsilence a break you just made.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
