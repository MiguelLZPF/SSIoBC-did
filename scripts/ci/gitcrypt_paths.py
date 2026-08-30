#!/usr/bin/env python3
"""Decide whether a file's CONTENT may be judged, or only its path.

A git-crypt encrypted path checks out as ciphertext wherever no key is held,
which is every CI runner. Every content-based rule then measures the encryption
rather than the document: the first docs-lint run in the repo this came from
failed five encrypted docs for having no `## Table of Contents` when all five
have one in plaintext. A locally generated baseline cannot cover them either,
because locally they decrypt.

So a content check on a git-crypt path is meaningless by construction, and it
is skipped everywhere, consistently. Path-only checks (placement, filename)
still apply: they read the path, which is never encrypted.

Two independent tests, on purpose:

  attribute   the path matches a `filter=git-crypt` pattern in some
              `.gitattributes`. True whether the file is locked or unlocked,
              so a local run and a CI run agree.
  content     the bytes start with the git-crypt magic, or are not valid
              UTF-8. Catches a locked file whose attribute this parser missed,
              and any other binary that reached a `.md` path.

The attribute test is parsed here rather than shelled out to `git check-attr`
so the self-tests can build a fixture tree with no repository in it, and so a
missing git binary cannot turn the skip off.

A repo with no git-crypt at all pays nothing for this: the rule list comes back
empty and only the cheap magic-byte sniff runs.
"""
import fnmatch
import functools
import pathlib

GITCRYPT_MAGIC = b"\x00GITCRYPT"
_SNIFF_BYTES = 8192


def _parse_gitattributes(path: pathlib.Path, scope: str):
    """Yield (scope, pattern, is_gitcrypt) for one .gitattributes file.

    `is_gitcrypt` is True for `filter=git-crypt`, False for an explicit
    `!filter` / `filter=` unset. Lines saying nothing about `filter` are not
    yielded at all, so they cannot override an earlier rule.
    """
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        tokens = line.split()
        pattern, attrs = tokens[0], tokens[1:]
        for attr in attrs:
            if attr == "filter=git-crypt":
                yield (scope, pattern, True)
                break
            if attr in ("!filter", "-filter") or attr.startswith("filter="):
                yield (scope, pattern, False)
                break


@functools.lru_cache(maxsize=8)
def _rules(root_str: str):
    """Every filter rule in the tree, shallowest scope first.

    Order matters: git applies a deeper `.gitattributes` after a shallower
    one, and a later line after an earlier one, so the LAST match wins.
    """
    root = pathlib.Path(root_str)
    found = []
    for f in root.rglob(".gitattributes"):
        if ".git" in f.relative_to(root).parts[:-1]:
            continue
        scope = f.parent.relative_to(root).as_posix()
        scope = "" if scope == "." else scope
        found.append((scope.count("/") if scope else -1, scope, f))
    rules = []
    for _, scope, f in sorted(found, key=lambda t: (t[0], t[1])):
        rules.extend(_parse_gitattributes(f, scope))
    return tuple(rules)


def reset_cache():
    """Forget the parsed rules. Only the self-tests need this."""
    _rules.cache_clear()


def _matches(scope: str, pattern: str, path: str) -> bool:
    """gitattributes matching, narrowed to the shapes these repos use.

    A pattern with no `/` matches the BASENAME at any depth below the scope;
    one with a `/` is anchored to the scope. Deliberately more permissive than
    git for `**`-ish patterns: over-matching here only skips a content check
    that the magic-byte test would skip anyway, while under-matching would
    reinstate the CI failure this exists to prevent.
    """
    if scope:
        prefix = scope + "/"
        if not path.startswith(prefix):
            return False
        rel = path[len(prefix):]
    else:
        rel = path
    pattern = pattern.lstrip("/")
    if "/" in pattern:
        return fnmatch.fnmatch(rel, pattern)
    return fnmatch.fnmatch(pathlib.PurePosixPath(rel).name, pattern)


def is_gitcrypt_path(root: pathlib.Path, path: str) -> bool:
    """True when `.gitattributes` routes `path` through the git-crypt filter."""
    verdict = False
    for scope, pattern, is_crypt in _rules(str(root)):
        if _matches(scope, pattern, path):
            verdict = is_crypt
    return verdict


def looks_encrypted_or_binary(full: pathlib.Path) -> bool:
    """True when the bytes on disk cannot be read as a text document."""
    try:
        head = full.open("rb").read(_SNIFF_BYTES)
    except OSError:
        return True
    if head.startswith(GITCRYPT_MAGIC):
        return True
    if b"\x00" in head:
        return True
    try:
        full.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return True
    return False


def readable_text(root: pathlib.Path, path: str, full: pathlib.Path):
    """The document's text, or None when its content must not be judged.

    None means the same thing in an unlocked checkout and a locked one, which
    is the whole point: the attribute test fires either way.
    """
    if is_gitcrypt_path(root, path):
        return None
    if looks_encrypted_or_binary(full):
        return None
    try:
        return full.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None
