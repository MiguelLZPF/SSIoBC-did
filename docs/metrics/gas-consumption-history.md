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

## Method-Level Gas Analysis

*The figures below predate the dual-variant architecture and are kept for historical continuity. For the latest measured values (v1.5.0, both variants), see the [v1.5.0 Gas Snapshot](#v150-gas-snapshot-september-2026) under Gas Evolution by Version.*

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
Traditional DID systems (ERC-1056) require event reconstruction, making historical queries expensive. SSIoBC-did trades higher creation cost for:
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

## Research Validation

### Academic Performance Claims

#### Thesis Validation Data
- **DID Creation**: 249,448 gas validates practical feasibility
- **Full On-chain Storage**: Cost-competitive with hybrid approaches
- **W3C Compliance**: No performance penalty for standard adherence

#### Comparison with Related Work
- **ERC-1056**: Lower creation cost, higher resolution cost
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

*Last Updated: v1.5.0 - Added isAuthorizedOffChainWithSigner() (ERC-1271 contract-signer verification), conformant DID-string rendering, `onlyDirectEOA` thinning (also carries v1.4.0's msg.sender migration, never tagged separately). See the v1.5.0 Gas Snapshot for full measured figures; v1.2.2 through v1.3.1 are not measured in this pass.*