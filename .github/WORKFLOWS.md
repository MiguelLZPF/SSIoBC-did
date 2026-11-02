# CI/CD Workflows

## Table of Contents

- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Triggers](#triggers)
- [Why There Is No Paths Filter](#why-there-is-no-paths-filter)
- [Toolchain Pin](#toolchain-pin)
- [Jobs](#jobs)
  - [shell - Network Wrapper Lint](#shell---network-wrapper-lint)
  - [changes - Path Decision](#changes---path-decision)
  - [build - Compile and Size Check](#build---compile-and-size-check)
  - [test - Test Suite](#test---test-suite)
  - [coverage - Coverage Analysis](#coverage---coverage-analysis)
  - [quality - Format and Lint](#quality---format-and-lint)
  - [security - Slither Security Scan](#security---slither-security-scan)
  - [gas-diff - Gas Comparison](#gas-diff---gas-comparison)
  - [thorough - Thorough Property Tests](#thorough---thorough-property-tests)
- [Docs Lint Workflow](#docs-lint-workflow)
- [Configuration](#configuration)
- [Concurrency](#concurrency)
- [Artifacts](#artifacts)
- [PR Automation](#pr-automation)
- [Branch Protection](#branch-protection)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

---

## Overview

Two workflows live in `.github/workflows/`:

- `ci.yml`: the Foundry pipeline, nine jobs (`shell`, `changes`, `build`, `test`, `coverage`, `quality`, `security`, `gas-diff`, `thorough`).
- `docs-lint.yml`: documentation link and placement checks, one job (`docs`).

`ci.yml` replaced two earlier overlapping workflows (`test.yml` and `ai-quality-check.yml`) in February 2026.

## Pipeline Architecture

```
  shell (independent)

  changes ──► build ──┬──► test
   sol=true?          ├──► coverage
                      ├──► quality
                      ├──► security
                      ├──► gas-diff   (PR, or push to main)
                      └──► thorough   (push to main only)
```

`build` runs only when `changes` reports `sol=true`. Every other Foundry job needs `build`, so a skipped `build` skips the whole chain. `shell` does not depend on `changes`.

## Triggers

| Event | Condition |
|-------|-----------|
| `pull_request` | opened, synchronize, reopened |
| `push` | branch `main` |
| `workflow_dispatch` | manual; optional `skip-security` input; always runs the full suite |

## Why There Is No Paths Filter

The workflow has no `paths:` filter on purpose. A workflow skipped by a paths filter publishes none of its checks, so each required check stays "Pending" and a branch that requires them can never be merged (see GitHub's note on [skipping workflow runs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs)). The path decision therefore lives in the `changes` job, which always runs and lets the expensive jobs skip themselves. A skipped job counts as passing for a required check, so a documentation-only pull request still merges.

## Toolchain Pin

The six Foundry jobs (`build`, `test`, `coverage`, `quality`, `gas-diff`, `thorough`) run inside `ghcr.io/foundry-rs/foundry@sha256:0c00cb0b...` (Foundry v1.8.1), pinned by digest, not tag. This is the same build developers run locally, and nothing is downloaded at job time. The previous `foundry-rs/foundry-toolchain` action fetched a fresh `foundryup` installer on every run; pinning the action by SHA pinned the wrapper but not that installer, and an upstream change broke a pinned workflow on 2026-08-26. The `docs/metrics/` gas and size numbers depend on a reproducible toolchain.

The container runs with `--user root` because the image declares `USER foundry` and the runner work directory is not writable by it. `security` is not containerised (see below).

## Jobs

### shell - Network Wrapper Lint

**Purpose**: Lints and self-tests `scripts/network.sh`.

- `shellcheck --severity=warning scripts/network.sh`
- `./scripts/network.sh --test`
- Independent of `changes`: it is cheap, needs no Foundry, and must run when only `scripts/`, `networks/` or the Makefile change.

**Required status check**: No

### changes - Path Decision

**Purpose**: Decides whether the Foundry jobs have anything to test.

- Uncontainerised, always runs, full history checkout (`fetch-depth: 0`).
- Output `sol` is `true` when the diff touches `src/`, `test/` or `script/` `.sol` files, `foundry.toml`, or `.github/workflows/ci.yml`; otherwise `false`.
- Diff range: base...head on a pull request, `before..sha` on a push.
- Fails open to `sol=true` on a manual dispatch, and when no diff range can be resolved (first push to a branch, force-push whose parent is gone).
- Writes the decision to the Step Summary.

**Required status check**: No

### build - Compile and Size Check

**Purpose**: Compiles all contracts and validates EIP-170 (24 KB) deployment size limits.

- Runs only when `changes` reports `sol=true`.
- Prints `forge --version` into the Step Summary.
- Runs `forge build --sizes`; fails if any contract's runtime size exceeds 24,576 bytes.
- Posts the size table to the Step Summary.
- Saves `out/` and `cache/` to the Actions cache (key `build-${{ github.sha }}`) for downstream jobs.

**Required status check**: Yes (`build`)

### test - Test Suite

**Purpose**: Runs the unit, fuzz, invariant and integration tests.

- `FOUNDRY_PROFILE=ci` (256 fuzz runs; invariants 64 runs, depth 32; fuzz and invariant tests included).
- Runs `forge test -vv --no-match-path "test/{stress,performance}/*"`, so stress and performance tests are left to `thorough`.
- 10-minute timeout.

**Required status check**: Yes (`test`)

### coverage - Coverage Analysis

**Purpose**: Enforces minimum 90% line coverage on source contracts.

- `FOUNDRY_PROFILE=ci`, same stress and performance exclusion as `test`.
- Generates LCOV via `forge coverage --report lcov`, then filters out `test/`, `script/` and `lib/` with `lcov`.
- Hard-fails if line coverage is below 90%.
- On pull requests, posts a coverage comment for the changed files (`romeovs/lcov-reporter-action`).
- Uploads raw and filtered LCOV as the `coverage-report` artifact (30 days).

**Required status check**: Yes (`coverage`)

### quality - Format and Lint

**Purpose**: Enforces code style.

- `forge fmt --check` (configured in `foundry.toml`)
- `forge lint` (exclusions in `foundry.toml [lint]`)

**Required status check**: Yes (`quality`)

### security - Slither Security Scan

**Purpose**: Static analysis for common smart contract vulnerabilities.

- Deliberately not containerised: `crytic/slither-action` is a Docker action and cannot run inside a container job. Slither brings its own solc, so the Foundry pin does not affect it.
- Skipped for Dependabot pull requests and when `skip-security` is set on a manual dispatch.
- Filters out `lib/`, `test/`, `script/`.
- `continue-on-error: true` and `fail-on: none`: findings never fail the job.
- Uploads SARIF as the `slither-sarif` artifact (30 days). It is not pushed to the GitHub Security tab, because `codeql-action/upload-sarif` needs `security-events: write`, which this job does not hold.

**Required status check**: No (advisory)

### gas-diff - Gas Comparison

**Purpose**: Compares gas costs between a pull request and its base.

- Runs on pull requests (not Dependabot) and on push to `main`. Both halves are load-bearing: the push run publishes `main.gasreport.ansi`, the only baseline the compare step on a pull request can find.
- `FOUNDRY_PROFILE=ci`, excludes stress and performance tests, 30-minute timeout.
- Deterministic fuzz seed (`FOUNDRY_FUZZ_SEED`): the PR's base commit, or `github.sha` on a push. A PR against `main` at commit X fuzzes with the seed the `main` run at X used, so a reported diff means the code moved rather than the sample.
- The gas report lists only `DidManager`, `DidManagerNative`, `W3CResolver` and `W3CResolverNative` (`gas_reports` in the `ci` profile), because test scaffolding getters would add noise.
- `Rubilmax/foundry-gas-diff` compares the reports (p90 quantile, sorted by avg then max); a sticky comment is posted on pull requests only.

**Required status check**: No (informational)

> **A note on `No workflow run found with an artifact named "main.gasreport.ansi"`.** If this appears, the baseline is genuinely missing and the diff below it is meaningless. While the job ran only on pull requests, no run produced that artifact and every comparison ran against an empty reference, reporting `0 diffs` while going green.

### thorough - Thorough Property Tests

**Purpose**: Full property testing after merge.

- Runs only on push to `main`; 30-minute timeout.
- `FOUNDRY_PROFILE=ci_thorough`: fuzz 1000 runs, invariants 256 runs at depth 64.
- Runs `forge test -vv` with no path exclusion, so stress and performance tests run here and nowhere else in CI.

**Required status check**: No

## Docs Lint Workflow

`docs-lint.yml` has one job, `docs`, running:

- `python3 scripts/ci/check-doc-links.py --all` (links, paths and cited commit hashes resolve)
- `python3 scripts/ci/check-doc-placement.py --all` (document placement and naming)

It triggers on push and pull request when `**/*.md`, `scripts/ci/check-doc-*.py`, `scripts/ci/doc-lint-config.json` or the workflow file change, weekly (Monday 06:17 UTC) and on manual dispatch. The weekly sweep exists because link rot happens when a target moves, which a changed-files trigger cannot see. The checkout uses full history so cited SHAs can be resolved.

Unlike `ci.yml`, this workflow does use a paths filter. That is why `docs` is deliberately **not** a required check: on a pull request that touches no Markdown the workflow never starts, and a required check would sit "Pending" forever.

## Configuration

### CI Profiles

Set in `foundry.toml`:

| Profile | Fuzz runs | Invariant | Used by |
|---------|-----------|-----------|---------|
| `default` | 256 | excluded (`no_match_test = "testFuzz\|invariant"`) | local `forge test` |
| `ci` | 256 | 64 runs, depth 32 | `test`, `coverage`, `gas-diff` |
| `ci_thorough` | 1000 | 256 runs, depth 64 | `thorough` |

Both CI profiles override `no_match_test` so fuzz and invariant tests run.

## Concurrency

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- **Pull requests**: a new push cancels the in-progress run for the same PR.
- **Push to main**: runs are queued, not cancelled, so every merge is validated.

`docs-lint.yml` uses its own group (`docs-lint-${{ github.ref }}`) and always cancels in-progress runs.

## Artifacts

| Artifact | Job | Retention | Purpose |
|----------|-----|-----------|---------|
| `coverage-report` | coverage | 30 days | Raw and filtered LCOV reports |
| `slither-sarif` | security | 30 days | Slither SARIF output |
| `main.gasreport.ansi` | gas-diff | per the compare action | Gas baseline from `main` |

## PR Automation

Pull requests receive:

1. **Coverage comment**: line coverage for changed files (`lcov-reporter-action`).
2. **Gas diff comment**: sticky comment with gas changes (`foundry-gas-diff` and `sticky-pull-request-comment`).
3. **Contract sizes**: in the `build` job's Step Summary.

## Branch Protection

The `default` ruleset on `main` requires four status checks: `build`, `test`, `coverage`, `quality`. Because `changes` skips them on documentation-only changes, they still report and the pull request can merge.

Not required, on purpose: `security` and `gas-diff` (advisory), `shell`, `changes`, `thorough` (main only), and `docs` from `docs-lint.yml` (path-filtered, see above).

A second ruleset, `release-tags`, protects release tags.

## Maintenance

- **Foundry version**: change the image digest and its trailing version comment together, in all six containerised jobs.
- **Action versions**: pinned by SHA, updated by Dependabot (`.github/dependabot.yml`) with weekly PRs.
- **Coverage threshold**: 90, set in the coverage job's shell script.
- **Lint exclusions**: `foundry.toml` under `[lint]`.
- **Filter list in `changes`**: if a new directory holds Solidity the Foundry jobs must test, add it to the `grep -qE` pattern in `ci.yml`.

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Build cache miss in downstream jobs | Cache key uses `github.sha`; `build` must run first | Keep `needs: build` |
| Required checks show as skipped on a docs PR | `changes` reported `sol=false` | Expected; a skipped required job passes |
| Gas diff reports an empty baseline | No `main.gasreport.ansi` from a push run on `main` | Wait for the push run on `main`, then re-run |
| Coverage check fails with empty `$COVERAGE` | `lcov` grep pattern mismatch | Check `lcov --summary` output format |
| Slither action fails | Solc version mismatch or dependency issues | Check `crytic/slither-action` version |
| `forge lint` exit 0 but shows notes | Notes are non-blocking; only errors fail | Configure `exclude_lints` for false positives |
