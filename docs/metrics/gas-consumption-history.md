# Gas Consumption History

## Table of Contents

- [Overview](#overview)
- [Gas Evolution by Version](#gas-evolution-by-version)
- [Method-Level Gas Analysis](#method-level-gas-analysis)
- [Cost Analysis](#cost-analysis)
- [Performance Optimizations](#performance-optimizations)
- [Research Validation](#research-validation)
- [Technical Implementation](#technical-implementation)
- [References](#references)

## Overview

This document tracks gas consumption evolution across SSIoBC-did versions, providing critical performance data for the PhD research on fully on-chain DID document management systems. Gas efficiency directly impacts the practical viability of complete on-chain DID storage.

## Gas Evolution by Version

### Early Development Phase (v0.1.0 - v0.3.0)

#### Gas Evidence by Version

- [v1.6.0 gas report (`forge test --gas-report`)](../assets/data/gasreport-v1.6.0.txt)
- [v1.7.0 gas report (`forge test --gas-report`)](../assets/data/gasreport-v1.7.0.txt)

**From v1.6.0 the evidence is text, not an image.** A screenshot of a terminal cannot be grepped,
diffed, or checked by a linter, so nobody notices when it stops matching the tables above it, and a
reader cannot copy a number out of it. The raw command output is committed instead: it carries a
provenance header naming the commit, the tag, the toolchain and the exact command, and a reviewer
can diff two releases directly. The images below stay as the historical record for v0.1.0 to
v1.5.0.

#### Individual Gas Reports
- [v0.1.0 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.1.0.png)
- [v0.1.1 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.1.1.png)
- [v0.1.2 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.1.2.png)
- [v0.1.3 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.1.3.png)
- [v0.1.4 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.1.4.png)
- [v0.2.0 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.2.0.png)
- [v0.3.0 Gas Report](../assets/screenshots/gas-consumption/Gas%20v0.3.0.png)

### Comprehensive Testing Phase (v0.4.0 - v0.8.0)

#### Combined Test & Gas Reports
- [v0.4.0 Test & Gas Report](../assets/screenshots/gas-consumption/Test%20&%20Gas%20v0.4.0.png)
- [v0.5.0 Test & Gas Report](../assets/screenshots/gas-consumption/Test%20&%20Gas%20v0.5.0.png)
- [v0.6.0 Test & Gas Report](../assets/screenshots/gas-consumption/Test%20&%20Gas%20v0.6.0.png)
- [v0.7.0 Test & Gas Report](../assets/screenshots/gas-consumption/Test%20&%20Gas%20v0.7.0.png)
- [v0.8.0 Test & Gas Report](../assets/screenshots/gas-consumption/Test%20&%20Gas%20v0.8.0.png)

### v1.5.0 Gas Snapshot (September 2026)

Measured with `FOUNDRY_PROFILE=ci forge test --gas-report --no-match-path "test/{stress,performance}/*"`, the exact command the `gas-diff` CI job runs. 396 tests executed.

#### DidManager (Full W3C variant)
```
| Function                        | Min    | Avg     | Median  | Max       | Calls |
|----------------------------------|--------|---------|---------|-----------|-------|
| createDid                       | 22,120 | 276,115 | 284,029 | 284,405   | 8,534 |
| createVm                        | 30,040 | 178,694 | 271,506 | 336,681   | 5,546 |
| deactivateDid                   | 24,480 | 45,888  | 51,757  | 56,760    | 30    |
| reactivateDid                   | 24,480 | 47,848  | 59,130  | 68,701    | 14    |
| updateController                | 27,480 | 54,330  | 41,563  | 98,308    | 3,862 |
| updateService                   | 29,030 | 203,892 | 215,271 | 2,007,937 | 55    |
| validateVm                      | 28,814 | 35,513  | 35,551  | 35,551    | 556   |
| isVmRelationship                | 688    | 17,748  | 17,770  | 22,156    | 3,162 |
| isAuthorized                    | 752    | 28,985  | 30,190  | 34,583    | 279   |
| isAuthorizedOffChain            | 719    | 32,179  | 33,706  | 38,100    | 282   |
| isAuthorizedOffChainWithSigner  | 876    | 16,206  | 9,784   | 38,139    | 18    |
```

#### DidManagerNative
```
| Function                        | Min     | Avg     | Median  | Max     | Calls |
|----------------------------------|---------|---------|---------|---------|-------|
| createDid                       | 22,120  | 206,994 | 212,330 | 212,706 | 9,216 |
| createVm                        | 27,360  | 141,704 | 186,333 | 254,662 | 6,654 |
| deactivateDid                   | 24,480  | 35,326  | 35,161  | 42,846  | 20    |
| reactivateDid                   | 22,680  | 34,079  | 28,355  | 56,982  | 12    |
| updateController                | 29,885  | 43,367  | 29,933  | 86,678  | 4,562 |
| updateService                   | 203,481 | 213,634 | 203,637 | 248,705 | 9     |
| validateVm                      | 28,544  | 33,341  | 33,354  | 33,354  | 1,053 |
| isVmRelationship                | 666     | 6,021   | 6,029   | 6,029   | 1,801 |
| isAuthorized                    | 730     | 13,514  | 18,264  | 22,657  | 1,558 |
| isAuthorizedOffChain            | 719     | 21,314  | 21,802  | 21,802  | 266   |
| isAuthorizedOffChainWithSigner  | 876     | 12,446  | 12,338  | 26,234  | 7     |
```

#### Resolvers
```
| Contract          | Function       | Min     | Avg     | Median  | Max       | Calls |
|-------------------|----------------|---------|---------|---------|-----------|-------|
| W3CResolver       | resolve        | 350,625 | 446,164 | 358,972 | 1,205,212 | 43    |
| W3CResolver       | resolveService | 646     | 23,251  | 17,279  | 51,828    | 3     |
| W3CResolver       | resolveVm      | 795     | 87,292  | 115,721 | 145,360   | 3     |
| W3CResolver       | checkMethods   | 259     | 6,710   | 5,485   | 15,610    | 268   |
| W3CResolverNative | resolve        | 341,308 | 420,904 | 383,719 | 568,584   | 21    |
| W3CResolverNative | resolveService | 646     | 46,379  | 51,724  | 86,768    | 3     |
| W3CResolverNative | resolveVm      | 795     | 98,468  | 123,610 | 130,027   | 5     |
```

**Key changes since v1.2.1:**
- **isAuthorizedOffChainWithSigner()** (new, v1.5.0): ERC-1271 contract-signer verification on the off-chain read path, both variants
- **onlyDirectEOA thinned** to `_requireDirectEOA()`: CHANGELOG.md reports about 22 gas more per guarded write call, in exchange for 158 bytes saved per manager
- **msg.sender-based authentication** (recorded in CHANGELOG.md as v1.4.0, folded into this release and never tagged separately): ID entropy and VM binding now use `msg.sender` instead of `tx.origin`

These figures are not directly comparable function-for-function to the v1.2.1 numbers elsewhere in this document: no consolidated gas-report table was captured for v1.2.2 through v1.3.1, and this pass does not check out those tags to produce one (see the gap note below).

**Versions not measured in this pass:** v1.2.2, v1.2.3, v1.2.4, v1.3.0, v1.3.1 would each require checking out their tag and re-running the gas report at that commit; this update does not check out any tag other than the one already checked out (v1.5.0). v1.4.0 was never tagged (per CHANGELOG.md) and its changes ship as part of v1.5.0 above.

### v1.6.0 Gas Snapshot (September 2026)

Same command as the v1.5.0 snapshot, run under Foundry 1.8.1 and solc 0.8.36: `FOUNDRY_PROFILE=ci forge test --gas-report --no-match-path "test/{stress,performance}/*"`. 383 tests executed, which is the same suite as v1.5.0's 396: forge 1.8.1 counts an invariant suite as one test rather than one per `invariant_` function, and 396 - 15 + 2 = 383.

**Read the Median column, not Avg.** Forge 1.8.1 reports far fewer calls per function than 1.5.1 did for the identical suite (`createDid` 8,534 -> 4,220, `createVm` 5,546 -> 1,763), so the mean is taken over a different sample and a v1.5.0/v1.6.0 mean delta measures the harness, not the contract. The median is stable across the change and is what the delta table below uses.

#### DidManager (Full W3C variant)
```
| Function                        | Min    | Avg     | Median  | Max       | Calls |
|----------------------------------|--------|---------|---------|-----------|-------|
| createDid                       | 22,120 | 267,969 | 283,813 | 284,405   | 4,220 |
| createVm                        | 30,040 | 230,196 | 271,506 | 336,681   | 1,763 |
| deactivateDid                   | 24,480 | 45,888  | 51,757  | 56,760    | 30    |
| reactivateDid                   | 24,480 | 47,848  | 59,130  | 68,701    | 14    |
| updateController                | 27,480 | 55,073  | 41,563  | 98,308    | 619   |
| updateService                   | 29,030 | 203,896 | 215,271 | 2,007,937 | 55    |
| validateVm                      | 28,814 | 35,514  | 35,551  | 35,551    | 558   |
| isVmRelationship                | 688    | 17,749  | 17,770  | 22,156    | 3,266 |
| isAuthorized                    | 752    | 28,989  | 30,190  | 34,583    | 280   |
| isAuthorizedOffChain            | 719    | 32,185  | 33,706  | 38,100    | 283   |
| isAuthorizedOffChainWithSigner  | 876    | 16,162  | 9,735   | 38,037    | 18    |
```

#### DidManagerNative
```
| Function                        | Min     | Avg     | Median  | Max     | Calls |
|----------------------------------|---------|---------|---------|---------|-------|
| createDid                       | 22,120  | 201,089 | 212,114 | 212,706 | 4,388 |
| createVm                        | 27,360  | 185,806 | 186,333 | 254,662 | 2,238 |
| deactivateDid                   | 24,480  | 35,326  | 35,161  | 42,846  | 20    |
| reactivateDid                   | 22,680  | 34,079  | 28,355  | 56,982  | 12    |
| updateController                | 29,897  | 43,320  | 29,933  | 86,678  | 602   |
| updateService                   | 203,481 | 213,634 | 203,637 | 248,705 | 9     |
| validateVm                      | 28,544  | 33,341  | 33,354  | 33,354  | 1,057 |
| isVmRelationship                | 666     | 6,021   | 6,029   | 6,029   | 1,808 |
| isAuthorized                    | 730     | 12,974  | 18,264  | 22,657  | 1,564 |
| isAuthorizedOffChain            | 719     | 21,316  | 21,802  | 21,802  | 267   |
| isAuthorizedOffChainWithSigner  | 876     | 12,404  | 12,240  | 26,133  | 7     |
```

#### Resolvers
```
| Contract          | Function       | Min     | Avg     | Median  | Max       | Calls |
|-------------------|----------------|---------|---------|---------|-----------|-------|
| W3CResolver       | resolve        | 350,673 | 448,282 | 359,020 | 1,205,452 | 42    |
| W3CResolver       | resolveService | 646     | 23,251  | 17,279  | 51,828    | 3     |
| W3CResolver       | resolveVm      | 795     | 87,292  | 115,721 | 145,360   | 3     |
| W3CResolver       | checkMethods   | 259     | 7,046   | 7,013   | 15,610    | 269   |
| W3CResolverNative | resolve        | 341,404 | 421,041 | 383,863 | 568,776   | 21    |
| W3CResolverNative | resolveService | 646     | 46,379  | 51,724  | 86,768    | 3     |
| W3CResolverNative | resolveVm      | 795     | 98,468  | 123,610 | 130,027   | 5     |
```

**Median gas, v1.5.0 -> v1.6.0:**

| Contract | Function | v1.5.0 | v1.6.0 | Change | Change (%) |
|---|---|---|---|---|---|
| DidManager | createDid | 284,029 | 283,813 | -216 | -0.08% |
| DidManager | isAuthorizedOffChainWithSigner | 9,784 | 9,735 | -49 | -0.50% |
| DidManagerNative | createDid | 212,330 | 212,114 | -216 | -0.10% |
| DidManagerNative | isAuthorizedOffChainWithSigner | 12,338 | 12,240 | -98 | -0.79% |
| W3CResolver | resolve | 358,972 | 359,020 | +48 | +0.01% |
| W3CResolverNative | resolve | 383,719 | 383,863 | +144 | +0.04% |

Every other function in the three tables above is byte-for-byte the same median as v1.5.0.

**Reading these numbers:** no headline operation moves by 1%, so this release does not disturb the cost tables under [Cost Analysis](#cost-analysis) and `gas-costs-2025.md` is deliberately left unedited. The `createDid` saving of 216 gas on both variants is solc 0.8.36's codegen, consistent with both managers also shrinking in bytecode; the resolvers are byte-identical yet their `resolve` medians move slightly because `resolve` reads through the manager.

One figure looks alarming and is not: `W3CResolver.checkMethods` moves from a 5,485 median to 7,013. It is an `external pure` helper that nothing in the contract calls, exercised only by fuzzed input, and its Min and Max are unchanged at 259 and 15,610. The distribution of the fuzz sample moved, not the function.

### v1.7.0 Gas Snapshot (October 2026)

Measured on 2026-10-27 at commit `6f54f55` (`src/` and `test/` are the release content), Foundry 1.8.1, solc 0.8.36, evm osaka, `optimizer_runs = 200`: `FOUNDRY_PROFILE=ci forge test --gas-report --no-match-path "test/{stress,performance}/*"`. 428 tests executed. The tables are the Min, Avg, Median, Max and Calls columns of that report, in the shape of the v1.6.0 snapshot.

**Read the Median column, and read the delta table as indicative only.** The test suite grew between v1.6.0 and v1.7.0 (the behaviour-lock tests, the list-limit tests at 255 VMs), so each function is measured over a different set of calls. Two cases show it: `W3CResolver.resolveService` reads 17,279 then 40,083 because the v1.6.0 median was taken over three calls that mostly hit an empty list, and the `resolve` Max columns (24,213,554 and 17,068,388) come from the new 255-VM tests. The reliable comparison is the same-test-set one below.

**Same test set, gas pass only (PR #42).** Both sides ran the PR's final test set, the baseline with `src/` checked out from the commit before the pass (`5555ebd`), so each test is compared with itself:

| Measure (branch head `356c60b`) | Baseline | After | Change |
|---|---:|---:|---:|
| `forge snapshot`, all 407 tests | | | -26,269,439 gas (-9.14%) |
| `forge test --isolate`, sum of per-test gas, 393 tests | 260,567,167 | 235,746,522 | -24,820,645 (-9.53%) |
| Tests whose gas rose / fell (isolate) | | | 0 / 346 |

**Per-test totals at the release commit.** `forge snapshot` and `forge test --isolate` give the same per-test gas here: 402 non-fuzz tests sum to 880,146,675 gas in both runs (the 24 fuzz tests, reported as a mean per run, add 9,665,404 in the isolate run). The `--isolate` run changes the call-level medians only slightly: of the headline functions, only `W3CResolver.resolve` differs (217,570 isolated against 217,128 shared-state). Raw outputs were kept outside the repository; the committed evidence is the gas report above.

#### DidManager
```
| Function | Min | Avg | Median | Max | Calls |
|---|---|---|---|---|---|
| createDid | 22,120 | 263,097 | 278,089 | 278,681 | 4,369 |
| createVm | 30,040 | 245,789 | 254,031 | 389,292 | 2,510 |
| deactivateDid | 24,480 | 36,137 | 39,818 | 44,844 | 31 |
| reactivateDid | 24,480 | 40,194 | 47,207 | 57,090 | 14 |
| updateController | 27,480 | 45,358 | 29,786 | 86,369 | 609 |
| updateService | 29,030 | 185,751 | 186,234 | 1,996,009 | 857 |
| validateVm | 28,814 | 35,321 | 35,357 | 35,357 | 559 |
| isVmRelationship | 688 | 6,111 | 6,117 | 6,117 | 3,252 |
| isAuthorized | 752 | 17,026 | 17,578 | 21,992 | 294 |
| isAuthorizedOffChain | 719 | 20,159 | 21,094 | 25,497 | 283 |
| isAuthorizedOffChainWithSigner | 876 | 11,976 | 9,735 | 25,434 | 18 |
```

#### DidManagerNative
```
| Function | Min | Avg | Median | Max | Calls |
|---|---|---|---|---|---|
| createDid | 22,120 | 201,009 | 211,700 | 212,292 | 4,525 |
| createVm | 27,360 | 184,148 | 185,629 | 253,958 | 2,724 |
| deactivateDid | 24,480 | 35,417 | 35,169 | 42,575 | 21 |
| reactivateDid | 22,680 | 33,994 | 28,284 | 57,024 | 12 |
| updateController | 29,897 | 44,930 | 29,933 | 86,392 | 588 |
| updateService | 44,518 | 184,406 | 186,147 | 248,435 | 294 |
| validateVm | 28,544 | 33,344 | 33,354 | 33,354 | 1,583 |
| isVmRelationship | 666 | 6,021 | 6,029 | 6,029 | 1,808 |
| isAuthorized | 730 | 12,216 | 17,550 | 21,964 | 1,578 |
| isAuthorizedOffChain | 719 | 20,620 | 21,088 | 21,088 | 267 |
| isAuthorizedOffChainWithSigner | 876 | 12,143 | 12,240 | 25,428 | 7 |
```

#### Resolvers
```
| Contract | Function | Min | Avg | Median | Max | Calls |
|---|---|---|---|---|---|---|
| W3CResolver | resolve | 210,542 | 1,180,713 | 217,128 | 24,213,554 | 54 |
| W3CResolver | resolveService | 646 | 32,341 | 40,083 | 63,402 | 5 |
| W3CResolver | resolveVm | 795 | 98,376 | 109,429 | 118,782 | 10 |
| W3CResolver | checkMethods | 259 | 7,124 | 7,695 | 15,610 | 271 |
| W3CResolverNative | resolve | 192,069 | 1,331,884 | 240,078 | 17,068,388 | 32 |
| W3CResolverNative | resolveService | 646 | 41,482 | 40,192 | 63,298 | 5 |
| W3CResolverNative | resolveVm | 795 | 75,456 | 83,884 | 89,379 | 9 |
```


Each median comes from its own release's test suite. v1.7.0 added tests, so a median can also move because the mix of calls changed, not only because the code did. The per-test comparison above (-9.14% snapshot, -9.53% isolate, same test set) is the measure of the code change; this table is kept for continuity with earlier releases.

**Median gas, v1.6.0 -> v1.7.0 (functions whose median moved; cross-suite, not the effect of the code alone):**

| Contract | Function | v1.6.0 | v1.7.0 | Change | Change (%) |
|---|---|---|---|---|---|
| DidManager | createDid | 283,813 | 278,089 | -5,724 | -2.02% |
| DidManager | createVm | 271,506 | 254,031 | -17,475 | -6.44% |
| DidManager | deactivateDid | 51,757 | 39,818 | -11,939 | -23.07% |
| DidManager | expireVm | 54,961 | 43,933 | -11,028 | -20.07% |
| DidManager | isAuthorized | 30,190 | 17,578 | -12,612 | -41.78% |
| DidManager | isAuthorizedOffChain | 33,706 | 21,094 | -12,612 | -37.42% |
| DidManager | reactivateDid | 59,130 | 47,207 | -11,923 | -20.16% |
| DidManager | updateController | 41,563 | 29,786 | -11,777 | -28.34% |
| DidManager | updateService | 215,271 | 186,234 | -29,037 | -13.49% |
| DidManager | validateVm | 35,551 | 35,357 | -194 | -0.55% |
| DidManagerNative | createDid | 212,114 | 211,700 | -414 | -0.20% |
| DidManagerNative | createVm | 186,333 | 185,629 | -704 | -0.38% |
| DidManagerNative | deactivateDid | 35,161 | 35,169 | +8 | +0.02% |
| DidManagerNative | expireVm | 43,325 | 44,031 | +706 | +1.63% |
| DidManagerNative | isAuthorized | 18,264 | 17,550 | -714 | -3.91% |
| DidManagerNative | isAuthorizedOffChain | 21,802 | 21,088 | -714 | -3.27% |
| DidManagerNative | reactivateDid | 28,355 | 28,284 | -71 | -0.25% |
| DidManagerNative | updateService | 203,637 | 186,147 | -17,490 | -8.59% |
| W3CResolver | resolve | 359,020 | 217,128 | -141,892 | -39.52% |
| W3CResolver | resolveVm | 115,721 | 109,429 | -6,292 | -5.44% |
| W3CResolverNative | resolve | 383,863 | 240,078 | -143,785 | -37.46% |
| W3CResolverNative | resolveVm | 123,610 | 83,884 | -39,726 | -32.14% |

**Reading these numbers (cross-suite medians, see the note above the table):** `isAuthorized` falls by 12,612 gas on `DidManager` (-41.78%), `resolve` by 141,892 (-39.52%) on `W3CResolver` and 143,785 (-37.46%) on `W3CResolverNative`, and every state-changing call on `DidManager` that checks a VM relationship falls by about 11,000 to 12,000 gas. The Native variant barely moves because its VM is already a single packed slot, so a memory copy was one SLOAD. Native `expireVm` is the one rise (+706, +1.63%); it comes from a different call mix, not from a code change in that function. `resolve` at 255 verification methods costs 25,858,238 gas on `W3CResolver` and 18,984,153 on `W3CResolverNative` (`includeExpired = false`, as logged by `ListLimits.unit.t.sol`), both under the 50,000,000 gas default `eth_call` cap of geth.

**Cost tables.** `createDid` on `DidManager` moved by -2.02%, which is above the 1% bar, so `gas-costs-2025.md` carries a v1.7.0 entry at the document's fixed 2025 market baseline.

## Method-Level Gas Analysis

*The figures below predate the dual-variant architecture and are kept for historical continuity. For the latest measured values (v1.7.0, both variants), see the [v1.7.0 Gas Snapshot](#v170-gas-snapshot-october-2026) under Gas Evolution by Version.*

### Core DID Operations

#### DID Creation (`createDid`)
- **Current Gas Cost**: ~283,506 gas (median)
- **Optimization**: Hash-based ID generation with pseudorandom elements
- **Components**:
  - ID generation: `keccak256(methods, random, tx.origin, block.prevrandao)`
  - Storage mapping updates
  - Event emission

#### DID Deactivation (`deactivateDid`)
- **Current Gas Cost**: ~51,696 gas (median, optimized from ~63,159 in v1.0.2 via direct storage reads)
- **Operation**: Sets DID expiration to 0 (permanent deactivation)
- **Authorization**: Requires controller or self-sovereign owner

#### DID Reactivation (`reactivateDid`) - v1.0.2
- **Self-Reactivation**: ~48,229 gas (median, owner reactivating own DID)
- **Controller Reactivation**: ~68,463 gas (max, controller reactivating another DID)
- **Operation**: Restores DID expiration to 4 years from current timestamp
- **Authorization**: Self-reactivation validates VM ownership; controller reactivation requires active controller DID
- **Note**: Preserves all VMs, Services, and Controllers during deactivation/reactivation cycle

#### Verification Method Operations
- **Add VM**: ~75,000-90,000 gas (varies by VM type)
- **Remove VM**: ~35,000-45,000 gas
- **Update VM**: ~65,000-80,000 gas
- **Optimization**: EnumerableSet for O(1) operations

#### Service Endpoint Operations
- **Add Service**: ~70,000-85,000 gas
- **Remove Service**: ~30,000-40,000 gas
- **Update Service**: ~60,000-75,000 gas

#### Controller Management
- **Add Controller**: ~45,000-55,000 gas
- **Remove Controller**: ~25,000-35,000 gas
- **Fixed Array**: Maximum 5 controllers for gas predictability

### Deployment Costs

#### Full System Deployment
- **Total Gas**: 2,803,776 gas
- **Components**:
  - DidManager deployment
  - VMStorage inheritance
  - ServiceStorage inheritance
  - W3CResolver deployment

## Cost Analysis

### Current Gas Prices (Research Baseline)
- **Gas Price**: 3.174 Gwei
- **ETH Price**: €1,600
- **Base Transaction**: ~21,000 gas

### Operation Costs (EUR)

#### DID Operations
- **Create DID**: €1.44 (~283,522 gas)
- **Deactivate DID**: €0.32 (~63,159 gas)
- **Reactivate DID (self)**: €0.31 (~61,450 gas)
- **Reactivate DID (controller)**: €0.44 (~86,492 gas)
- **Full Deployment**: €14.24 (2,803,776 gas)
- **Add VM**: €0.43 (average 82,500 gas)
- **Add Service**: €0.39 (average 77,500 gas)
- **Controller Update**: €0.25 (average 50,000 gas)

#### Comparative Analysis
Measured against ERC-1056 in [ERC-1056 Gas Comparison](../analysis/research-validation.md#erc-1056-gas-comparison). SSIoBC-did trades higher write cost for:
- **Direct Storage Access**: No event parsing required
- **Immediate Resolution**: W3C-compliant response in single call
- **Predictable Costs**: Fixed gas patterns for all operations

## Performance Optimizations

### Hash-Based List Architecture
1. **EnumerableSet Integration**: O(1) add/remove/contains operations
2. **Position-Hash Mapping**: Efficient VM validation
3. **Minimal Storage Access**: Reduced SSTORE operations

### Gas Reduction Strategies
1. **Immutable Architecture**: No proxy pattern overhead
2. **Native Signature Integration**: Uses transaction signatures directly
3. **Packed Storage**: Efficient struct packing for gas savings
4. **Event Optimization**: Minimal but complete event emission

### Version Improvements
- **v0.1.0-v0.2.0**: Basic functionality establishment
- **v0.3.0**: VM expiration logic optimization
- **v0.4.0-v0.6.0**: Testing integration and gas profiling
- **v0.7.0-v0.8.0**: Final optimizations and W3C resolver completion
- **v1.1.0**: Bytecode optimization (custom errors, dead code removal, SLOAD caching, HashUtils library, direct storage reads, optimizer_runs=200)
- **v1.2.0**: Dual-variant architecture (DidManagerNative with 1-slot VMs reduces per-operation gas for Ethereum-only DIDs)
- **v1.2.1**: Added isAuthorized() view function (+412/+411 bytes), removed redundant authenticate(). Net gas impact: negligible (view-only addition)
- **v1.5.0**: Added isAuthorizedOffChainWithSigner() (ERC-1271 contract-signer verification), conformant DID-string rendering, `onlyDirectEOA` thinned to an internal-function guard; also carries v1.4.0's msg.sender migration (never tagged separately). See [v1.5.0 Gas Snapshot](#v150-gas-snapshot-september-2026) for full measured figures
- **v1.6.0**: Toolchain only (Foundry 1.8.1, solc 0.8.36, forge-std 1.16.2, OpenZeppelin 5.7.0). No source change; `createDid` median falls 216 gas on both variants and nothing else moves by 1%. See [v1.6.0 Gas Snapshot](#v160-gas-snapshot-september-2026)

## Research Validation

### Academic Performance Claims

#### Thesis Validation Data
- **DID Creation**: 249,448 gas validates practical feasibility
- **Full On-chain Storage**: Cost-competitive with hybrid approaches
- **W3C Compliance**: No performance penalty for standard adherence

#### Comparison with Related Work
- **ERC-1056**: measured per operation in [ERC-1056 Gas Comparison](../analysis/research-validation.md#erc-1056-gas-comparison)
- **EBSI**: Privacy-focused but requires mediators
- **LACChain**: Enhanced governance with bureaucratic overhead
- **ONCHAINID**: Pre-W3C standards with different gas patterns

### Performance Scalability
The gas consumption patterns demonstrate linear scalability:
- **Predictable Costs**: Each operation has consistent gas requirements
- **No State Bloat**: Efficient storage patterns prevent gas increases over time
- **Batch Operations**: Potential for future gas optimizations through batching

## Technical Implementation

### Gas Profiling Methodology
1. **Forge Gas Reports**: Standard foundry gas profiling
2. **Method-Level Tracking**: Individual function gas consumption
3. **State Change Analysis**: Gas cost attribution by storage operations
4. **Edge Case Testing**: Maximum capacity scenarios

### Optimization Techniques
1. **Storage Layout**: Optimal variable ordering for slot packing
2. **Function Modifiers**: Efficient access control patterns
3. **Event Design**: Minimal but complete information emission
4. **Error Handling**: Custom errors for gas efficiency

### Gas Limit Considerations
- **Block Gas Limit**: 30M gas (mainnet)
- **Transaction Headroom**: DID creation ~0.83% of block limit
- **Batch Potential**: Up to ~120 DID creations per block

## References

### Gas Report Archives
- Early phase reports: [v0.1.0-v0.3.0 Screenshots](../assets/screenshots/gas-consumption/)
- Comprehensive phase: [v0.4.0-v0.8.0 Test & Gas Reports](../assets/screenshots/gas-consumption/)

### Related Documentation
- [Contract Size History](./contract-size-history.md)
- [Test Coverage History](./test-coverage-history.md)
- [Performance Trends Analysis](../analysis/performance-trends.md)

### Research Context
Gas consumption data directly supports PhD thesis claims about:
- **Practical Feasibility**: €1.27 DID creation cost
- **Performance Efficiency**: Competitive with existing solutions
- **Scalability**: Linear gas growth with predictable patterns

### Academic References
Performance data referenced in:
- Main thesis: "SSIoBC – Decentralized Identifiers [X.XX].md"
- Research paper submissions
- Conference presentations on blockchain DID performance

---

*Last Updated: v1.7.0 (2026-10-27) - gas pass and list-limit fixes. See the v1.7.0 Gas Snapshot for the measured figures and the same-test-set comparison; v1.2.2 through v1.3.1 are not measured.*
