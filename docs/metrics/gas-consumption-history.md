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

## Method-Level Gas Analysis

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

*Last Updated: v1.2.1 - Added isAuthorized() cross-DID authorization view function, removed redundant authenticate()*