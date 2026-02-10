# CI/CD Workflows

## Table of Contents

- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Triggers](#triggers)
- [Jobs](#jobs)
  - [build - Compile and Size Check](#build---compile-and-size-check)
  - [test - Test Suite](#test---test-suite)
  - [coverage - Coverage Analysis](#coverage---coverage-analysis)
  - [quality - Format and Lint](#quality---format-and-lint)
  - [security - Slither Security Scan](#security---slither-security-scan)
  - [gas-diff - Gas Comparison](#gas-diff---gas-comparison)
- [Configuration](#configuration)
- [CI Profile](#ci-profile)
- [Concurrency](#concurrency)
- [Artifacts](#artifacts)
- [PR Automation](#pr-automation)
- [Branch Protection](#branch-protection)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

---

## Overview

The project uses a single unified workflow (`.github/workflows/ci.yml`) with 6 parallel jobs. This replaced two previous overlapping workflows (`test.yml` and `ai-quality-check.yml`) in February 2026.

**Foundry version**: Pinned to `v1.5.1` across all jobs for reproducible builds.

## Pipeline Architecture

```
                    +─────────────────+
                    │      build      │  ~45s
                    │ compile + sizes │
                    +────────┬────────+
           ┌─────────┬──────┴──────┬───────────┐
           ▼         ▼             ▼           ▼
     +──────────+ +──────────+ +─────────+ +──────────+
     │   test   │ │ coverage │ │ quality │ │ security │
     │   ~90s   │ │  ~120s   │ │  ~10s   │ │  ~60s    │
     +─────┬────+ +──────────+ +─────────+ +──────────+
           ▼
     +──────────+
     │ gas-diff │  PR only
     │   ~60s   │
     +──────────+
```

**Estimated total time**: ~3-4 min (limited by longest path: build -> coverage).

## Triggers

| Event | Condition | Scope |
|-------|-----------|-------|
| `pull_request` | opened, synchronize, reopened | `src/**/*.sol`, `test/**/*.sol`, `script/**/*.sol`, `foundry.toml`, `.github/workflows/ci.yml` |
| `push` | branches: `main`, `feat/**` | Same path filters as PR |
| `workflow_dispatch` | Manual trigger | Optional `skip-security` input |

The path filters ensure CI only runs when relevant files change, saving runner minutes.

## Jobs

### build - Compile and Size Check

**Purpose**: Compiles all contracts and validates EIP-170 (24KB) deployment size limits.

- Runs `forge build --sizes` and captures output
- Parses the "Runtime Size (B)" column; fails if any contract exceeds 24,576 bytes
- Posts contract sizes table to the GitHub Step Summary
- Saves `out/` and `cache/` to GitHub Actions cache for downstream jobs

**Required status check**: Yes

### test - Test Suite

**Purpose**: Runs the full test suite with enhanced fuzz testing.

- Uses `FOUNDRY_PROFILE=ci` (1,000 fuzz runs vs default 256)
- Runs `forge test -vv` for moderate verbosity
- Generates a gas snapshot (`.gas-snapshot`) for the gas-diff job
- Uploads gas snapshot as a 7-day artifact

**Required status check**: Yes

### coverage - Coverage Analysis

**Purpose**: Enforces minimum 90% line coverage on source contracts.

- Generates LCOV report via `forge coverage --report lcov`
- Installs `lcov` and filters out `test/`, `script/`, `lib/` paths
- Extracts line coverage percentage and **hard-fails if below 90%**
- On PRs: posts a detailed coverage comment via `romeovs/lcov-reporter-action` (only changed files)
- Uploads raw and filtered LCOV files as 30-day artifacts

**Required status check**: Yes

### quality - Format and Lint

**Purpose**: Enforces code style consistency.

- `forge fmt --check` — validates Foundry formatter compliance (configured in `foundry.toml`)
- `forge lint` — runs Foundry linter (excluded rules configured in `foundry.toml [lint]`)

**Required status check**: Yes

### security - Slither Security Scan

**Purpose**: Static analysis for common smart contract vulnerabilities.

- Uses the official `crytic/slither-action` (no pip install overhead)
- Filters out `lib/`, `test/`, `script/` paths
- Outputs SARIF format and uploads to GitHub Security tab via `codeql-action/upload-sarif`
- **Non-blocking**: `continue-on-error: true` and `fail-on: none`
- Can be skipped via `workflow_dispatch` with `skip-security: true`

**Required status check**: No (advisory only)

### gas-diff - Gas Comparison

**Purpose**: Compares gas costs between PR branch and base branch.

- **Runs only on pull requests**
- Uses deterministic fuzz seed (`FOUNDRY_FUZZ_SEED`) for reproducible gas numbers
- `Rubilmax/foundry-gas-diff` compares gas reports against the base branch
- Posts a sticky PR comment with gas changes (p90 quantile, sorted by avg/max)
- First run on a new branch may show an error (no baseline yet) — this is expected

**Required status check**: No (informational only)

## Configuration

### CI Profile

The `[profile.ci]` section in `foundry.toml` overrides defaults for CI runs:

```toml
[profile.ci]
fuzz = { runs = 1000 }       # 4x default (256)
verbosity = 2                 # -vv output
gas_reports = ["*"]           # Track all contracts
```

Activated by setting `FOUNDRY_PROFILE=ci` in the test job environment.

## Concurrency

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- **PRs**: New pushes cancel any in-progress CI run for the same PR (saves runner minutes)
- **Push to main/feat branches**: Runs are queued, not cancelled (ensures all pushes are validated)

## Artifacts

| Artifact | Job | Retention | Purpose |
|----------|-----|-----------|---------|
| `gas-snapshot` | test | 7 days | Gas snapshot for gas-diff comparison |
| `coverage-report` | coverage | 30 days | Raw and filtered LCOV reports |
| `slither-results.sarif` | security | Default | Uploaded to GitHub Security tab |

## PR Automation

Pull requests automatically receive:

1. **Coverage comment** — Line-by-line coverage for changed files (via `lcov-reporter-action`)
2. **Gas diff comment** — Sticky comment showing gas cost changes (via `foundry-gas-diff` + `sticky-pull-request-comment`)
3. **Slither findings** — Visible in the GitHub Security tab (SARIF upload)
4. **Contract sizes** — Available in the build job's Step Summary

## Branch Protection

Recommended required status checks for `main`:

- `Build & Size Check` (build)
- `Tests` (test)
- `Coverage` (coverage)
- `Format & Lint` (quality)

The `Security Scan` and `Gas Diff` jobs are intentionally **not** required — they are advisory.

## Maintenance

- **Foundry version**: Pinned to `v1.5.1`. Update in all 6 jobs when upgrading.
- **Action versions**: Managed by Dependabot (`.github/dependabot.yml`) with weekly PRs.
- **Coverage threshold**: Set to 90% in the coverage job's shell script. Adjust the `90` value if the threshold changes.
- **Lint exclusions**: Configured in `foundry.toml` under `[lint] exclude_lints`.

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Build cache miss in downstream jobs | Cache key uses `github.sha`; build must run first | Ensure `needs: build` is present |
| Gas diff shows error on first PR | No baseline data on the base branch yet | Expected on first run; resolves after merge |
| Coverage check fails with empty `$COVERAGE` | `lcov` grep pattern mismatch | Check `lcov --summary` output format |
| Slither action fails | Solc version mismatch or dependency issues | Check `crytic/slither-action` version compatibility |
| `forge lint` exit 0 but shows notes | Notes/warnings are non-blocking; only errors fail | Expected behavior; configure `exclude_lints` for false positives |
