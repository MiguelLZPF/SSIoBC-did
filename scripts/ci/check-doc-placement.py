#!/usr/bin/env python3
"""Refuse a `.md` that lands somewhere the placement map does not allow.

A placement rule without a lint is a suggestion. That has been measured twice:
the no-AI-attribution rule was violated 51 times as prose and stopped at zero
once a hook existed. So the map gets a lint.

Four checks, all on `.md` files:

  placement   an ADDED file must sit under one of the config's `doc_roots`, be
              a `README.md` under one of its `readme_only_roots`, or be one of
              the root-allowlisted names.
  naming      lowercase-kebab-case. `README.md` is the documented exception;
              the root allowlist and the harness filenames (`SKILL.md`,
              `PULL_REQUEST_TEMPLATE.md`, ...) under a harness root are exempt
              too, because those names are fixed by tools outside the repo.
  toc         over `toc_line_threshold` lines, a doc needs `## Table of
              Contents` or an explicit `<!-- toc-exempt -->` marker. SKIPPED on
              a git-crypt path: see gitcrypt_paths.py. A CI runner holds no key,
              so it would be reading ciphertext and judging the encryption
              rather than the document.
  index-row   no table row of an `index_files` document may exceed
              `index_row_max` characters. An index is priming, not storage: a
              fact that lives only in a row is invisible to anyone reading the
              doc it points at.

PER-REPO CONFIG. Everything above comes from `scripts/ci/doc-lint-config.json`,
written by the installer from the repo's real layout. The defaults below apply
when that file is absent. Nothing in this script is specific to one repository.

GRANDFATHERING. Existing violations are pinned in
`scripts/ci/doc-placement-baseline.txt`, regenerated with --write-baseline. A
baselined path passes when it is MODIFIED; an ADDED path is always judged, so
the baseline can never be used to re-introduce debt under an old name.

Modes:

    check-doc-placement.py                # staged changes (pre-commit)
    check-doc-placement.py --all          # whole tree (CI, weekly)
    check-doc-placement.py --write-baseline
    check-doc-placement.py --test         # self-test, no repo needed
"""
import fnmatch
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gitcrypt_paths  # noqa: E402  (sibling module, path fixed above)

BASELINE = pathlib.Path("scripts/ci/doc-placement-baseline.txt")
CONFIG_FILE = pathlib.Path(os.path.dirname(os.path.abspath(__file__))) / "doc-lint-config.json"

DEFAULTS = {
    # Any .md may live anywhere below these.
    "doc_roots": ["docs", "docs-private", ".claude", ".github", "archive"],
    # Only a README.md may live below these.
    "readme_only_roots": ["scripts", "src", "test", "tests", "clusters", "data"],
    # Filenames allowed at the repository root.
    "root_allowlist": [
        "README.md",
        "CLAUDE.md",
        "PROJECT.md",
        "MEMORY.md",
        "AGENTS.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "CODE_OF_CONDUCT.md",
        "LICENSE.md",
    ],
    # Names whose case is fixed by a tool outside the repo, under a harness root.
    "harness_roots": [".claude", ".github"],
    "harness_names": [
        "SKILL.md",
        "AGENTS.md",
        "CLAUDE.md",
        "MEMORY.md",
        "README.md",
        "PULL_REQUEST_TEMPLATE.md",
        "ISSUE_TEMPLATE.md",
        "WORKFLOWS.md",
    ],
    # Vendored or generated trees. Judged by nobody, so not judged here.
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
    "toc_line_threshold": 100,
    "index_row_max": 1000,
    "index_files": ["CLAUDE.md"],
}

KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*\.md$")
MD_LINK = re.compile(r"\]\(([^)]+)\)")


def load_config(root: pathlib.Path = None) -> dict:
    """DEFAULTS overlaid with the repo's own config, if it wrote one."""
    cfg = dict(DEFAULTS)
    for candidate in (CONFIG_FILE, (root / BASELINE.parent / CONFIG_FILE.name) if root else None):
        if candidate and candidate.is_file():
            try:
                cfg.update(json.loads(candidate.read_text()))
            except (OSError, ValueError):
                pass
            break
    return cfg


def excluded(cfg: dict, path: str) -> bool:
    for pat in cfg["exclude_globs"]:
        if fnmatch.fnmatch(path, pat) or path.startswith(pat.rstrip("*/") + "/"):
            return True
    return False


def placement_ok(cfg: dict, path: str) -> bool:
    """True when `path` is somewhere the placement map allows a .md to live."""
    p = pathlib.PurePosixPath(path)
    parts = p.parts
    if len(parts) == 1:
        return path in cfg["root_allowlist"]
    top = parts[0]
    if top in cfg["doc_roots"]:
        return True
    if top in cfg["readme_only_roots"]:
        return p.name == "README.md"
    return False


def naming_ok(cfg: dict, path: str) -> bool:
    p = pathlib.PurePosixPath(path)
    name = p.name
    if name == "README.md":
        return True
    if len(p.parts) == 1 and name in cfg["root_allowlist"]:
        return True
    if p.parts[0] in cfg["harness_roots"] and name in cfg["harness_names"]:
        return True
    return bool(KEBAB.match(name))


def toc_ok(cfg: dict, text: str) -> bool:
    lines = text.splitlines()
    if len(lines) <= cfg["toc_line_threshold"]:
        return True
    if "<!-- toc-exempt -->" in text:
        return True
    return any(ln.strip().lower().startswith("## table of contents") for ln in lines)


def row_key(row: str) -> str:
    """A stable-enough identity for an index-table row.

    The first link target in the row names the document the row is about, which
    survives the row being edited. Rows without a link fall back to a hash, and
    those simply stop being grandfathered once reworded -- acceptable, because a
    row with no link is not an index row.
    """
    m = MD_LINK.search(row)
    if m:
        return m.group(1).split("#")[0]
    return "sha1:" + hashlib.sha1(row.encode()).hexdigest()[:12]


def index_row_violations(cfg: dict, text: str):
    """Yield (key, length) for every over-long table row in an index doc."""
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        if len(line) > cfg["index_row_max"]:
            yield row_key(line), len(line)


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


def check_file(cfg: dict, root: pathlib.Path, path: str, added: bool, baseline):
    """Return a list of (code, key, message) violations for one .md path."""
    out = []
    if excluded(cfg, path):
        return out
    full = root / path

    def emit(code, key, msg):
        if not added and (code, key) in baseline:
            return
        out.append((code, key, msg))

    if not placement_ok(cfg, path):
        if added:
            # Placement is only judged unconditionally on ADD: a file already
            # living somewhere odd is history, and moving it is its own commit.
            out.append(("placement", path, f"{path}: not an allowed location for a .md"))
        else:
            emit("placement", path, f"{path}: not an allowed location for a .md")

    if not naming_ok(cfg, path):
        emit("naming", path, f"{path}: filename is not lowercase-kebab-case.md")

    if full.is_file():
        text = gitcrypt_paths.readable_text(root, path, full)
        if text is None:
            # Encrypted, binary or undecodable. The path was judged above;
            # the content is not ours to read and never will be in CI.
            return out
        if not toc_ok(cfg, text):
            emit(
                "toc",
                path,
                f"{path}: over {cfg['toc_line_threshold']} lines with no "
                "'## Table of Contents' (or <!-- toc-exempt -->)",
            )
        if path in cfg["index_files"]:
            for key, length in index_row_violations(cfg, text):
                emit(
                    "index-row",
                    key,
                    f"{path}: index row for {key} is {length} chars "
                    f"(cap {cfg['index_row_max']})",
                )
    return out


def staged_md(root: pathlib.Path):
    """[(path, added)] for staged .md changes."""
    proc = subprocess.run(
        ["git", "diff", "--cached", "--name-status", "--diff-filter=ACMR"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    out = []
    for line in proc.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) < 2:
            continue
        status, path = fields[0], fields[-1]
        if not path.endswith(".md"):
            continue
        out.append((path, status.startswith(("A", "R"))))
    return out


def all_md(root: pathlib.Path):
    proc = subprocess.run(
        ["git", "ls-files", "-z", "*.md"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    return [(p, False) for p in proc.stdout.split("\0") if p]


def repo_root() -> pathlib.Path:
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return pathlib.Path.cwd()
    return pathlib.Path(proc.stdout.strip())


def run(root: pathlib.Path, targets, baseline, cfg=None):
    cfg = cfg or load_config(root)
    violations = []
    for path, added in targets:
        violations.extend(check_file(cfg, root, path, added, baseline))
    return violations


def write_baseline(root: pathlib.Path):
    # A baseline is what EXISTS, so every file is judged as modified.
    violations = run(root, all_md(root), set())
    lines = sorted({f"{code} {key}" for code, key, _ in violations})
    body = (
        "# Grandfathered doc-placement violations. Generated by\n"
        "#   scripts/ci/check-doc-placement.py --write-baseline\n"
        "# A listed path passes when MODIFIED; an ADDED path is always judged.\n"
        "# Shrinking this file is the point. Never add a line by hand.\n"
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
    cfg["readme_only_roots"] = list(cfg["readme_only_roots"]) + ["clusters"]

    def check(name, cond):
        if cond:
            print(f"  ok   {name}")
        else:
            print(f"  FAIL {name}")
            failures.append(name)

    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        (root / "clusters" / "home").mkdir(parents=True)
        (root / "docs").mkdir()
        (root / "scripts" / "ci").mkdir(parents=True)
        (root / "lib" / "forge-std").mkdir(parents=True)

        # 1. a bad-location ADD fails
        (root / "clusters" / "home" / "notes.md").write_text("hi\n")
        v = run(root, [("clusters/home/notes.md", True)], set(), cfg)
        check("bad-location add fails", any(c == "placement" for c, _, _ in v))

        # 2. the same path, MODIFIED and baselined, passes
        base = {("placement", "clusters/home/notes.md")}
        v = run(root, [("clusters/home/notes.md", False)], base, cfg)
        check("baselined modified path passes", not v)

        # 2b. baselined but ADDED still fails -- the baseline is not a bypass
        v = run(root, [("clusters/home/notes.md", True)], base, cfg)
        check("baselined path still fails on ADD", any(c == "placement" for c, _, _ in v))

        # 2c. a vendored tree is not judged at all
        (root / "lib" / "forge-std" / "CHANGELOG.md").write_text("hi\n")
        v = run(root, [("lib/forge-std/CHANGELOG.md", True)], set(), cfg)
        check("vendored path excluded", not v)

        # 3. an oversized index row fails
        long_row = "| [x](docs/x.md) | " + ("y" * 1100) + " |"
        (root / "CLAUDE.md").write_text("# t\n\n| a | b |\n|---|---|\n" + long_row + "\n")
        v = run(root, [("CLAUDE.md", False)], set(), cfg)
        check("oversized index row fails", any(c == "index-row" for c, _, _ in v))

        # 3b. and is grandfathered by its link target
        v = run(root, [("CLAUDE.md", False)], {("index-row", "docs/x.md")}, cfg)
        check("baselined index row passes", not v)

        # 3c. a row under the cap passes
        (root / "CLAUDE.md").write_text("# t\n\n| [x](docs/x.md) | short |\n")
        v = run(root, [("CLAUDE.md", False)], set(), cfg)
        check("short index row passes", not v)

        # 4. naming
        (root / "docs" / "Bad_Name.md").write_text("hi\n")
        v = run(root, [("docs/Bad_Name.md", True)], set(), cfg)
        check("SCREAMING/underscore name fails", any(c == "naming" for c, _, _ in v))
        (root / "docs" / "good-name.md").write_text("hi\n")
        v = run(root, [("docs/good-name.md", True)], set(), cfg)
        check("kebab name in docs/ passes", not v)
        (root / "scripts" / "ci" / "README.md").write_text("hi\n")
        v = run(root, [("scripts/ci/README.md", True)], set(), cfg)
        check("scripts README.md passes", not v)
        gh = root / ".github"
        gh.mkdir()
        (gh / "PULL_REQUEST_TEMPLATE.md").write_text("hi\n")
        v = run(root, [(".github/PULL_REQUEST_TEMPLATE.md", True)], set(), cfg)
        check("harness filename under .github passes", not v)

        # 5. ToC
        big = "# t\n" + "\n".join(f"line {i}" for i in range(150)) + "\n"
        (root / "docs" / "big.md").write_text(big)
        v = run(root, [("docs/big.md", True)], set(), cfg)
        check("long doc without ToC fails", any(c == "toc" for c, _, _ in v))
        (root / "docs" / "big-toc.md").write_text("# t\n\n## Table of Contents\n\n" + big)
        v = run(root, [("docs/big-toc.md", True)], set(), cfg)
        check("long doc with ToC passes", not v)
        (root / "docs" / "big-exempt.md").write_text("<!-- toc-exempt -->\n" + big)
        v = run(root, [("docs/big-exempt.md", True)], set(), cfg)
        check("toc-exempt marker passes", not v)

        # 6. git-crypt: content checks off, path checks still on.
        priv = root / "docs-private"
        priv.mkdir()
        (priv / ".gitattributes").write_text(
            "* filter=git-crypt diff=git-crypt\n.gitattributes !filter !diff\n"
        )
        gitcrypt_paths.reset_cache()

        # 6a. plaintext, long, no ToC -- would fail anywhere else
        (priv / "secret-doc.md").write_text(big)
        v = run(root, [("docs-private/secret-doc.md", True)], set(), cfg)
        check("git-crypt path: ToC not judged", not any(c == "toc" for c, _, _ in v))

        # 6b. the same file locked, as CI would see it
        (priv / "locked-doc.md").write_bytes(
            gitcrypt_paths.GITCRYPT_MAGIC + b"\x00\x01\x02" + big.encode()
        )
        v = run(root, [("docs-private/locked-doc.md", True)], set(), cfg)
        check("git-crypt path: ciphertext not judged", not v)

        # 6c. and the naming rule still bites, because it reads the path
        (priv / "Bad_Secret.md").write_bytes(gitcrypt_paths.GITCRYPT_MAGIC + b"\x00zz")
        v = run(root, [("docs-private/Bad_Secret.md", True)], set(), cfg)
        check("git-crypt path: naming still enforced", any(c == "naming" for c, _, _ in v))

        # 6d. magic bytes alone are enough, with no .gitattributes in sight
        (root / "docs" / "binary-doc.md").write_bytes(
            gitcrypt_paths.GITCRYPT_MAGIC + b"\x00" + big.encode()
        )
        v = run(root, [("docs/binary-doc.md", True)], set(), cfg)
        check("git-crypt magic outside docs-private: not judged", not v)

        # 7. the config is what decides, not the code
        narrow = dict(cfg)
        narrow["doc_roots"] = ["documentation"]
        v = run(root, [("docs/good-name.md", True)], set(), narrow)
        check("config drives placement", any(c == "placement" for c, _, _ in v))

    gitcrypt_paths.reset_cache()
    print(f"\n{'FAILED' if failures else 'PASSED'}: {len(failures)} failing case(s)")
    return 1 if failures else 0


def main() -> int:
    args = [a for a in sys.argv[1:] if a.startswith("--")]
    if "--test" in args:
        return selftest()

    root = repo_root()
    os.chdir(root)

    if "--write-baseline" in args:
        return write_baseline(root)

    targets = all_md(root) if "--all" in args else staged_md(root)
    if not targets:
        return 0

    violations = run(root, targets, read_baseline(root))
    if not violations:
        return 0

    print("Document placement violations:\n", file=sys.stderr)
    for _, _, msg in sorted(violations, key=lambda v: v[2]):
        print(f"  {msg}", file=sys.stderr)
    print(
        "\nThe map this enforces is scripts/ci/doc-lint-config.json."
        "\nA denial is fixed by moving or renaming the file, never by editing"
        f"\n{BASELINE} -- that file is grandfathering, not a bypass.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
