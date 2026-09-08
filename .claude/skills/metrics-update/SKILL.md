---
name: metrics-update
description: >
  Re-measure contract sizes, gas consumption and test coverage for this Foundry
  project, then append a dated version block to the tracked research artifacts in
  docs/metrics/ in the exact house format (progression table row, sizes block,
  delta table, committed text evidence). USE WHEN: update the metrics, update docs/metrics,
  refresh the gas numbers, record the new contract sizes, the sizes changed, gas
  went up after this change, add a version row to the size history, update the
  coverage history, we optimized something so record it, log this optimization,
  before tagging a release update the metrics, the metrics are stale, docs/metrics
  is behind, capture the gas impact of this refactor. DO NOT use for reading a
  one-off gas number (just run `forge test --gas-report`), for the CI gas-diff
  comment on a PR (that is automatic), or for editing docs/analysis/ documents.
model: sonnet
version: 1.0.0
---

# Metrics Update

Turns a code change into the four numbers this project publishes, and writes them into
`docs/metrics/` the way every previous release wrote them.

## Table of Contents

- [Why this is a procedure and not a habit](#why-this-is-a-procedure-and-not-a-habit)
- [Step 1 — Decide whether the change is worth recording](#step-1--decide-whether-the-change-is-worth-recording)
- [Step 2 — Measure](#step-2--measure)
- [Step 3 — Write the size history](#step-3--write-the-size-history)
- [Step 4 — Write the gas history](#step-4--write-the-gas-history)
- [Step 5 — Write the coverage history](#step-5--write-the-coverage-history)
- [Step 6 — Evidence and the ToC](#step-6--evidence-and-the-toc)
- [Step 7 — Verify and report](#step-7--verify-and-report)
- [Traps worth knowing](#traps-worth-knowing)

## Why this is a procedure and not a habit

`docs/metrics/` is a published research artifact, cited by `docs/analysis/research-validation.md`
and by the thesis this repository supports. A gas table that stops four releases ago is worse than
no table, because a reader cannot tell which numbers still describe the deployed code.

An instruction to "update the metrics for significant changes" has never been the missing piece;
the files still fell several releases behind. What is missing is the answer to "which of four
documents gets which of three measurements, in what shape", and that is what follows.

## Step 1 — Decide whether the change is worth recording

Record when any of these is true:

- a contract's runtime size moved by 50 bytes or more in either direction
- a headline operation's gas moved by 1% or more (`createDid`, `createVm`, `resolve`,
  `isAuthorized`, `createService`)
- coverage crossed a whole percentage point, or a contract's coverage changed category
- the release is being tagged, in which case record regardless of size (a "no source changes" row
  is a real row: see the `v1.2.2` and `v1.2.3` rows in the size table)

If none holds, say so and stop. A row per commit destroys the signal these tables exist to carry.

## Step 2 — Measure

Run all three from the repo root, on a clean tree, with the same profile the numbers were
historically taken under (the default profile, `optimizer_runs = 200`):

```bash
# Sizes — this is the same command CI runs in the `build` job
forge build --sizes 2>&1 | tee .temp/reports/sizes-$(git describe --tags --always).txt

# Gas — exclude stress/performance, exactly as the `gas-diff` CI job does,
# so the numbers stay comparable with previous releases
forge test --gas-report --no-match-path "test/{stress,performance}/*" \
  > .temp/reports/gasreport-$(git describe --tags --always).txt

# Coverage — CI profile, because the default profile skips fuzz and invariant tests
FOUNDRY_PROFILE=ci forge coverage --report summary \
  --no-match-path "test/{stress,performance}/*" \
  | tee .temp/reports/coverage-$(git describe --tags --always).txt
```

Non-code output belongs in `.temp/`, per the repo's file-organization rule. Create
`.temp/reports/` if it is not there.

Read the previous release's numbers before writing anything: without them there is no delta, and
the delta table is the part a reader actually uses.

```bash
grep -oE 'v1\.[0-9]+\.[0-9]+' docs/metrics/contract-size-history.md | sort -uV | tail -1
```

## Step 3 — Write the size history

`docs/metrics/contract-size-history.md` takes two edits.

**3a. One row appended to "Core Contracts Size Progression"**, six columns, sizes in kB to one
decimal. Bold the whole row when the release changed source; leave it plain when it did not.

```
| **vX.Y.Z** | **13.9 kB** | **12.3 kB** | **11.8 kB** | **12.4 kB** | **short architecture note** |
```

**3b. One `### vX.Y.Z <Title> (Month Year)` section under "Size Comparison Analysis"**, following
the shape used by every section from `v1.0` onward:

1. a one-paragraph summary of what changed
2. `#### vX.Y.Z Contract Sizes`, a fenced block holding the four-contract table with Runtime Size,
   Initcode Size, Runtime Margin and Initcode Margin, in **bytes**, taken verbatim from
   `forge build --sizes`
3. `**Key Changes:**`, a numbered list
4. `**Size Impact (vPREV → vNEW):**`, a table with previous bytes, new bytes, change and % change
5. `**Net impact**:` one sentence naming where the bytes went

The four contracts tracked are `DidManager`, `DidManagerNative`, `W3CResolver`,
`W3CResolverNative`, in that order in the sizes block and in the progression table.

## Step 4 — Write the gas history

`docs/metrics/gas-consumption-history.md`: update the per-operation tables under "Method-Level Gas
Analysis" and add a bullet under "Version Improvements". Take the numbers from the gas report's
mean column, not min or max, because that is what the existing rows are.

`docs/metrics/gas-costs-2025.md` only needs touching when a headline operation moved: it converts
gas into EUR at a stated gas price, so a changed gas figure invalidates the cost tables under
"Contract Deployment Costs" and "Create DID Transaction Costs". Update the numbers, not the
methodology, and leave the stated market assumptions alone unless the user asks.

## Step 5 — Write the coverage history

`docs/metrics/test-coverage-history.md`: append to the progression table, and update the per
contract rows under "Coverage Analysis by Component". Coverage below 90% is a CI failure, not a
metrics entry, so if the summary shows under 90% stop and report it rather than recording it.

## Step 6 — Evidence and the ToC

Each history file links its raw command output as evidence, committed under
`docs/assets/data/`:

Three files per release, named `sizes-`, `gasreport-` and `coverage-` followed by the version and
`.txt`. `docs/assets/data/sizes-v1.6.0.txt` is the worked example of all three.

| Filename stem | Keep | Source command |
|---|---|---|
| `sizes-` | the one `forge build --sizes` table | `forge build --sizes` |
| `gasreport-` | the four `src/` contract tables only | `FOUNDRY_PROFILE=ci forge test --gas-report --no-match-path "test/{stress,performance}/*"` |
| `coverage-` | the summary table | `FOUNDRY_PROFILE=ci forge coverage --report summary --no-match-path "test/{stress,performance}/*"` |

Every file starts with a provenance header, so a number can never be traced to the wrong build:

```
# SSIoBC-did <version> measurement evidence
# commit:  <full sha>  (tag <version>)
# toolchain: forge <ver> (<short sha>), solc <ver>, evm <target>, optimizer_runs 200
# deps:    forge-std <tag>, openzeppelin-contracts <tag>
# command: <the exact command>
# captured: YYYY-MM-DD
# note:    <the one thing a reader would otherwise misread>
```

Strip the compiler warnings and keep the tables; a reader wants the numbers, and noise is what
makes an evidence file go unread.

**Screenshots are no longer produced.** Versions v0.1.0 through v1.5.0 link PNGs under
`docs/assets/screenshots/`, and those stay as the historical record. They are not extended, because
an image of a terminal cannot be grepped, diffed or linted: nobody notices when it stops matching
the table above it, and a reader cannot copy a number out of it. Text can be diffed between two
releases directly, and `check-doc-links.py` can verify the link resolves.

Every file edited needs its Table of Contents updated. This is a repo-wide standard and it is
linted: `python3 scripts/ci/check-doc-links.py --all` runs in the `docs-lint` workflow.

## Step 7 — Verify and report

```bash
python3 scripts/ci/check-doc-links.py --all
python3 scripts/ci/check-doc-placement.py --all
git diff --stat docs/
```

Then report to the user: the four size deltas in bytes, the largest gas delta as a percentage, the
coverage figure, and which files you edited. Do not commit; the user commits, PGP-signed.

## Traps worth knowing

- **The default profile skips fuzz and invariant tests** (`no_match_test = "testFuzz|invariant"`
  in `foundry.toml`). Coverage measured without `FOUNDRY_PROFILE=ci` is not comparable to the
  historical figures and will read several points low.
- **Sizes are optimizer-dependent.** `optimizer_runs = 200` since v1.1.0. If you measure after
  changing it, the row is not comparable to anything above it and must say so.
- **Include stress and performance tests in nothing.** Both the `test` and `gas-diff` CI jobs
  exclude `test/{stress,performance}/*`; matching that exclusion is what makes local numbers and
  CI numbers agree.
- **The progression table uses kB, the analysis block uses bytes.** Mixing them is the most common
  error in these files.
- **A release with no source change still gets a row**, marked "no source changes". Gaps in the
  version column read as lost data.
