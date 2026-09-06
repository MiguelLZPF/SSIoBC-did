---
name: release-prep
description: >
  Walk the full pre-tag checklist for this repository before cutting a release:
  reconcile the version string across CHANGELOG.md, CITATION.cff, PROJECT.md and
  the README badges, write the changelog entry with its ToC row and compare link,
  confirm docs/metrics/ and the test catalog were refreshed, verify a clean tree
  and green CI, then create the GPG-signed annotated tag. USE WHEN: cut a release,
  prepare a release, release checklist, ready to tag, bump the version, tag v1.6.0,
  we are shipping this, prepare v1.6.0, what do I need to do before tagging, write
  the changelog entry for this release, is this ready to release, sync the version
  everywhere, finalize the release. DO NOT use for publishing to a package registry
  (this project publishes none), for deploying contracts to a network (that is
  script/DidManager.s.sol), or for writing a single changelog line mid-development.
model: sonnet
version: 1.0.0
---

# Release Prep

The version string lives in at least five places and nothing keeps them in step. This is the
checklist that does.

## Table of Contents

- [Why this exists](#why-this-exists)
- [The version surface](#the-version-surface)
- [Step 1 — Confirm the release is real](#step-1--confirm-the-release-is-real)
- [Step 2 — Choose the version](#step-2--choose-the-version)
- [Step 3 — CHANGELOG.md, all three parts](#step-3--changelogmd-all-three-parts)
- [Step 4 — Sync the other version carriers](#step-4--sync-the-other-version-carriers)
- [Step 5 — Confirm the derived documents were refreshed](#step-5--confirm-the-derived-documents-were-refreshed)
- [Step 6 — Gate on a clean tree and green CI](#step-6--gate-on-a-clean-tree-and-green-ci)
- [Step 7 — Tag](#step-7--tag)
- [Traps worth knowing](#traps-worth-knowing)

## Why this exists

Three separate omissions are sitting in the repository right now, and each is the kind a checklist
catches and memory does not:

- `PROJECT.md` closed with "Version: v1.3.0" while `CHANGELOG.md` documented 1.5.0, uncaught for two releases
- `git tag` lists `v1.3.1` then jumps straight to `v1.5.0`; the 1.4.0 release has a changelog entry
  and no tag
- the compare links at the bottom of `CHANGELOG.md` stop at `[1.2.1]`, so several releases have no
  diff link

None of these is a mistake of understanding. They are all coordination failures across files that
nothing checks together. Work the steps in order; the order is what makes the check reliable.

## The version surface

Every place the version appears. Touch all of them, or the next reader gets a contradiction.

| File | What carries the version | Notes |
|---|---|---|
| `CHANGELOG.md` | ToC row, `## [X.Y.Z] — YYYY-MM-DD` section, compare link at the bottom | three separate edits, all required |
| `CITATION.cff` | `version:` and `date-released:` | this is the citable artifact; the thesis references it |
| `PROJECT.md` | the `**Last Updated**` / `**Version**` trailer at the end | currently stale |
| `README.md` | the badge row: test count, Solidity version, coverage | only if those numbers moved |
| `CLAUDE.md` | the `**Last Updated**` trailer | only if the architecture summary changed |
| `docs/analysis/test-catalog.md` | the `**Last Updated**` trailer and the summary counts | see Step 5 |
| git | an annotated, GPG-signed tag `vX.Y.Z` | Step 7 |

## Step 1 — Confirm the release is real

```bash
git status --short
git log --oneline $(git describe --tags --abbrev=0)..HEAD
```

Read the commit list and decide what actually shipped. If the list is empty, or holds only
documentation commits, say so and ask whether a release is wanted rather than manufacturing one.

## Step 2 — Choose the version

Semantic versioning, as declared at the top of `CHANGELOG.md`. For a contract project the mapping
that matters:

- **MAJOR** when a function selector changes, is removed, or an existing call's authorization
  behaviour changes. The v1.5.0 entry is marked `feat!:` for exactly this reason.
- **MINOR** when a function is added, or behaviour changes in a way that breaks no existing caller.
- **PATCH** for tests, documentation, CI and gas work with no ABI or behaviour change.

State your proposed version and reasoning to the user and let them confirm before editing anything.
Getting this wrong is expensive: a tag, once pushed, is what other people pin against.

## Step 3 — CHANGELOG.md, all three parts

Follow Keep a Changelog, and copy the shape of the entry above the one you are writing.

**3a. Section.** `## [X.Y.Z] — YYYY-MM-DD` with an em-dash separator matching the existing headings,
then `### Added` / `### Changed` / `### Fixed` / `### Removed` as needed. Entries are written for a
reader who was not here: name the function, name the file, say what changed and why. The v1.5.0
entry is the standard to match, including its explicit statement of what is *not* yet possible.

**3b. ToC row**, at the top, newest first:

```markdown
- [1.6.0 — 2026-10-01](#160--2026-10-01)
```

The anchor is the heading lowercased with punctuation stripped; note the double hyphen from the
em dash. Get it wrong and `check-doc-links.py` fails.

**3c. Compare link**, appended at the bottom in the descending block:

```markdown
[1.6.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.5.0...v1.6.0
```

While here, backfill every missing entry. That block has not been maintained since `[1.2.1]`, so
`[1.5.0]`, `[1.3.1]`, `[1.3.0]`, `[1.2.4]`, `[1.2.3]` and `[1.2.2]` are all absent.

## Step 4 — Sync the other version carriers

```bash
# See every version string at once before editing
grep -n 'version:' CITATION.cff
grep -nE '^\*\*(Version|Last Updated)' PROJECT.md CLAUDE.md docs/analysis/test-catalog.md
grep -n 'img.shields.io' README.md
```

Edit each per the table in [The version surface](#the-version-surface). `CITATION.cff` needs both
`version` and `date-released`, and they must agree with the changelog date.

## Step 5 — Confirm the derived documents were refreshed

A release should not be tagged on stale metrics. Check, and if either is behind, do that work
first rather than tagging around it.

```bash
# Highest version present in each metrics document
for f in docs/metrics/*.md; do
  echo "$f -> $(grep -oE 'v1\.[0-9]+\.[0-9]+' "$f" | sort -uV | tail -1)"
done

# Documented test total vs actual test functions
grep -m1 -oE '\*\*[0-9]+\*\*' docs/analysis/test-catalog.md
for f in $(find test -name '*.t.sol'); do grep -cE '^\s*function (test|invariant)' "$f"; done \
  | awk '{s+=$1} END {print "actual:", s}'
```

If `docs/metrics/` lags, invoke the **metrics-update** skill; it owns that procedure and this one
should not duplicate it. If the test totals disagree, reconcile `docs/analysis/test-catalog.md`,
including the per-file counts embedded in its section headings and the README test badge.

## Step 6 — Gate on a clean tree and green CI

```bash
forge fmt --check
forge lint
forge build --sizes
FOUNDRY_PROFILE=ci forge test -vv --no-match-path "test/{stress,performance}/*"
python3 scripts/ci/check-doc-links.py --all
python3 scripts/ci/check-doc-placement.py --all
```

These mirror the `quality`, `build`, `test` and `docs-lint` jobs. Passing locally is necessary, not
sufficient: the `thorough` job runs only on push to main with `FOUNDRY_PROFILE=ci_thorough`
(fuzz 1000, invariant 256 × 64) plus the stress and performance suites. If the release changes
contract logic, run that too before tagging:

```bash
FOUNDRY_PROFILE=ci_thorough forge test -vv
```

Then confirm the branch is actually green on GitHub, not merely green here:

```bash
gh run list --branch main --limit 3
```

## Step 7 — Tag

Commits and tags in this project are PGP-signed; the existing tags are annotated objects with good
signatures. Match that.

```bash
git tag -s vX.Y.Z -m "Release vX.Y.Z"
git tag -v vX.Y.Z          # prove the signature is good BEFORE pushing
git push origin vX.Y.Z
```

Create the tag only after the release commit is pushed, and verify before pushing. A tag pointing
at an unpushed commit is a tag nobody else can resolve.

Report back: the version, the files changed, the metrics and catalog status, and the tag. Leave the
GitHub release notes to the user unless they ask.

## Traps worth knowing

- **Tag verification is not optional here.** `git tag -s` succeeds even when the signing key is
  wrong for the identity; `git tag -v` is what actually proves it.
- **The compare-link block is the part everyone forgets.** It is at the very bottom of a 23 KB
  file, below the oldest entry, so it never appears in the diff you are looking at.
- **`CITATION.cff` is not decoration.** It is the citable record for an academic project; a wrong
  version there propagates into other people's bibliographies and cannot be recalled.
- **Do not tag to fix a missed tag retroactively.** The 1.4.0 tag is missing. Creating it now would
  point at the wrong tree unless it is placed on the exact release commit, which
  `git log --oneline --all` can find. Raise it with the user rather than deciding alone.
- **The `thorough` CI job runs after the merge, not before it.** A property-test failure found by
  1000 fuzz runs surfaces on main, after the tag, unless you run `ci_thorough` yourself first.
