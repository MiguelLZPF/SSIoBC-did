# Contract Size History

## Table of Contents

- [Overview](#overview)
- [Version Evolution](#version-evolution)
- [Size Comparison Analysis](#size-comparison-analysis)
- [Optimization Impact](#optimization-impact)
- [Research Implications](#research-implications)
- [Technical Details](#technical-details)
- [References](#references)

## Overview

This document tracks the evolution of contract sizes across SSIoBC-did versions, supporting the PhD research on fully on-chain DID document management systems. The data demonstrates the progression from initial implementation to optimized four-contract architecture while maintaining W3C compliance.

## Version Evolution

### Core Contracts Size Progression

| Version | DidManager | W3CResolver | DidManagerNative | W3CResolverNative | Architecture Notes |
|---------|------------|-------------|------------------|-------------------|--------------------|
| v0.1.0  | ~10.5 kB   | N/A         | —                | —                 | Initial single-contract approach |
| v0.1.2  | ~11.2 kB   | ~9.8 kB     | —                | —                 | Separated resolver functionality |
| v0.1.3  | ~11.5 kB   | ~10.1 kB    | —                | —                 | Enhanced read functions |
| v0.1.4  | ~11.8 kB   | ~10.5 kB    | —                | —                 | Controller system improvements |
| v0.2.0  | ~12.1 kB   | ~11.2 kB    | —                | —                 | Service endpoint integration |
| v0.3.0  | ~12.3 kB   | ~11.8 kB    | —                | —                 | VM expiration functionality |
| v0.4.0  | ~12.2 kB   | ~12.1 kB    | —                | —                 | Service testing optimizations |
| v0.5.0  | ~12.1 kB   | ~12.3 kB    | —                | —                 | VM testing enhancements |
| v0.6.0  | ~12.0 kB   | ~12.5 kB    | —                | —                 | DidManager test coverage |
| v0.7.0  | ~11.9 kB   | ~12.7 kB    | —                | —                 | Performance optimizations |
| v0.8.0  | ~12.0 kB   | ~12.8 kB    | —                | —                 | W3C resolver completion |
| v1.0-pre | 14.3 kB   | 13.1 kB     | —                | —                 | VMStorage optimization + Base58 |
| v1.0    | 13.9 kB    | 12.4 kB     | —                | —                 | Pre-encoded multibase (Base58 removed) |
| v1.0.1  | 13.9 kB    | 12.8 kB     | —                | —                 | ServiceStorage optimization (dynamic bytes) |
| v1.0.2  | 15.2 kB    | 12.8 kB     | —                | —                 | reactivateDid() + _isVmOwner() helper |
| **v1.1.0** | **12.1 kB** | **12.8 kB** | **—** | **—** | **Bytecode optimization: custom errors, SLOAD caching, HashUtils, optimizer_runs=200** |
| **v1.2.0** | **12.1 kB** | **11.2 kB** | **10.5 kB** | **11.7 kB** | **Dual-variant architecture with shared DidManagerBase + publicKeyMultibase for keyAgreement** |
| **v1.2.1** | **12.6 kB** | **11.2 kB** | **10.9 kB** | **11.7 kB** | **Added isAuthorized() cross-DID authorization, removed redundant authenticate()** |
| v1.2.2 | 12.6 kB | 11.2 kB | 10.9 kB | 11.7 kB | Test hardening and config fixes (no source changes) |
| v1.2.3 | 12.6 kB | 11.2 kB | 10.9 kB | 11.7 kB | Import standardization and CI pinning (no logic changes) |
| **v1.2.4** | **12.5 kB** | **11.2 kB** | **10.8 kB** | **11.7 kB** | **Centralized parameter validation in DidManagerBase (-100 B each)** |

### Visual Documentation

#### Size Screenshots by Version
- [v0.1.0 Size Report](../assets/screenshots/contract-size/Size%20v0.1.0.jpeg)
- [v0.1.2 Size Report](../assets/screenshots/contract-size/Size%20v0.1.2.png)
- [v0.1.3 Size Report](../assets/screenshots/contract-size/Size%20v0.1.3.png)
- [v0.1.4 Size Report](../assets/screenshots/contract-size/Size%20v0.1.4.png)
- [v0.2.0 Size Report](../assets/screenshots/contract-size/Size%20v0.2.0.png)
- [v0.3.0 Size Report](../assets/screenshots/contract-size/Size%20v0.3.0.png)
- [v0.4.0 Size Report](../assets/screenshots/contract-size/Size%20v0.4.0.png)
- [v0.5.0 Size Report](../assets/screenshots/contract-size/Size%20v0.5.0.png)
- [v0.6.0 Size Report](../assets/screenshots/contract-size/Size%20v0.6.0.png)
- [v0.7.0 Size Report](../assets/screenshots/contract-size/Size%20v0.7.0.png)
- [v0.8.0 Size Report](../assets/screenshots/contract-size/Size%20v0.8.0.png)

## Size Comparison Analysis

### v1.0 Storage Optimization Analysis (February 2026)

The v1.0 release includes a comprehensive VMStorage optimization that traded increased contract size for significantly improved per-operation gas efficiency.

#### v0.8.0 (Before Storage Optimization)
```
| Contract    | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|-------------|------------------|-------------------|--------------------|--------------------|
| DidManager  | 12,081           | 12,434            | 12,495             | 36,718             |
| W3CResolver | 12,464           | 13,195            | 12,112             | 35,957             |
```

#### v1.0-pre (With Base58 Library)
```
| Contract    | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|-------------|------------------|-------------------|--------------------|--------------------|
| DidManager  | 14,317           | 14,345            | 10,259             | 34,807             |
| W3CResolver | 13,123           | 13,874            | 11,453             | 35,278             |
```

#### v1.0 (After Base58 Removal - Pre-encoded Multibase)
```
| Contract    | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|-------------|------------------|-------------------|--------------------|--------------------|
| DidManager  | 13,946           | 13,974            | 10,630             | 35,178             |
| W3CResolver | 12,429           | 13,180            | 12,147             | 35,972             |
```

#### v1.0.1 (ServiceStorage Optimization - Dynamic Bytes)
```
| Contract    | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|-------------|------------------|-------------------|--------------------|--------------------|
| DidManager  | 13,904           | 13,932            | 10,672             | 35,220             |
| W3CResolver | 12,846           | 13,597            | 11,730             | 35,555             |
```

#### Size Changes Summary (v0.8.0 → v1.0)
| Contract | v0.8.0 (B) | v1.0 (B) | Change | % Change |
|----------|------------|----------|--------|----------|
| DidManager | 12,081 | 13,946 | +1,865 | +15.4% |
| W3CResolver | 12,464 | 12,429 | -35 | -0.3% |

#### v1.0 Optimization: Pre-encoded Multibase

The v1.0 release removes the OpenZeppelin Base58 library from W3CResolver by storing pre-encoded multibase strings instead of raw bytes + multicodec.

**Key Changes:**
1. **Base58 Library Removed**: Eliminated ~694 bytes from W3CResolver
2. **Pre-encoded Input**: Callers now provide multibase strings (e.g., "zQ3shok...") instead of raw bytes
3. **Simplified Resolution**: W3CResolver now performs simple bytes→string conversion

**Size Impact (v1.0-pre → v1.0):**
| Contract | Before (B) | After (B) | Savings | % Change |
|----------|-----------|----------|---------|----------|
| W3CResolver | 13,123 | 12,429 | -694 | -5.3% |
| DidManager | 14,317 | 13,946 | -371 | -2.6% |

### v1.0.1 ServiceStorage Optimization Analysis (February 2026)

The v1.0.1 release transforms ServiceStorage from fixed `bytes32[20][4]` arrays (161 slots per service) to dynamic bytes (~6 slots typical), achieving 96% storage reduction per service.

**Key Changes:**
1. **Dynamic Bytes Storage:** Service types and endpoints now use `bytes` instead of fixed arrays
2. **Null Delimiter:** Multiple types/endpoints packed with `\x00` separator
3. **Flexible Limits:** Max 500 bytes for types, 2000 bytes for endpoints
4. **W3CResolver Parsing:** Added `_parsePackedStrings()` for delimiter-based parsing

**Size Impact (v1.0 → v1.0.1):**
| Contract | v1.0 (B) | v1.0.1 (B) | Change | % Change |
|----------|----------|----------|--------|----------|
| DidManager | 13,946 | 13,904 | -42 | -0.3% |
| W3CResolver | 12,429 | 12,846 | +417 | +3.4% |

**Storage Efficiency Impact:**
| Metric | v1.0 (Fixed Arrays) | v1.0.1 (Dynamic Bytes) | Improvement |
|--------|---------------------|----------------------|-------------|
| Storage per service | 161 slots (5,152 B) | ~6 slots (192 B) | 96% reduction |
| Gas (create service) | ~3,200,000 gas | ~227,000 gas | 93% reduction |
| Gas (delete service) | ~1,600,000 gas | ~25,000 gas | 98% reduction |

**Trade-off:** W3CResolver increased by 417 bytes (+3.4%) due to added parsing logic, but this is offset by massive per-service storage and gas savings.

### v1.0.2 Reactivation Feature Analysis (February 2026)

The v1.0.2 release adds the `reactivateDid()` function, enabling deactivated DIDs to be reactivated by their owner or an active controller.

#### v1.0.2 Contract Sizes
```
| Contract    | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|-------------|------------------|-------------------|--------------------|--------------------|
| DidManager  | 15,159           | 15,187            | 9,417              | 33,965             |
| W3CResolver | 12,846           | 13,597            | 11,730             | 35,555             |
```

**Key Changes:**
1. **reactivateDid() Function**: New public function in DidManager for reactivating deactivated DIDs
2. **_isVmOwner() Helper**: New internal function in VMStorage for ownership validation without expiration check
3. **Dual Reactivation Modes**: Self-reactivation (owner) and controller-reactivation (active controller)
4. **DidNotDeactivated Error**: New custom error for attempting to reactivate active DIDs
5. **DidReactivated Event**: New event emitted on successful reactivation

**Size Impact (v1.0.1 → v1.0.2):**
| Contract | v1.0.1 (B) | v1.0.2 (B) | Change | % Change |
|----------|----------|----------|--------|----------|
| DidManager | 13,904 | 15,159 | +1,255 | +9.0% |
| W3CResolver | 12,846 | 12,846 | 0 | 0% |

**Gas Costs for New Functions:**
| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| reactivateDid (self) | ~61,450 | Owner reactivating own DID |
| reactivateDid (controller) | ~86,492 | Controller reactivating another DID |
| deactivateDid | ~63,159 | For comparison |

**Security Model:**
- Self-reactivation validates VM ownership without expiration check (DID is deactivated but VMs preserved)
- Controller-reactivation requires active controller DID with valid authentication VM
- Only deactivated DIDs (expiration == 0) can be reactivated
- VMs, Services, and Controllers are preserved across deactivation/reactivation cycle

**Trade-off:** DidManager increased by 1,255 bytes (+9.0%) to add secure reactivation capability, enabling DID lifecycle recovery while maintaining W3C compliance.

### v1.1.0 Bytecode Size Optimization (February 2026)

Following v1.0.2's size increase, a systematic bytecode optimization was performed to reduce DidManager's runtime size while improving gas efficiency.

#### v1.1.0 Contract Sizes
```
| Contract    | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|-------------|------------------|-------------------|--------------------|--------------------|
| DidManager  | 12,102           | 12,130            | 12,474             | 37,022             |
| W3CResolver | 12,846           | 13,597            | 11,730             | 35,555             |
```

**Optimizations Applied:**

| Step | Description | Bytes Saved | Cumulative |
|------|-------------|-------------|------------|
| 1 | Replace `require(string)` with custom errors in ServiceStorage | -149 | -149 |
| 2 | Remove dead code in `_isVmRelationship` (always-true condition) | -82 | -231 |
| 3 | Cache double SLOAD in `_isExpired` | -28 | -259 |
| 4 | Deduplicate hash helpers into HashUtils library | 0 | -259 |
| 5 | Direct storage reads in `_isControllerFor` (avoid memory copy) | -183 | -442 |
| 6 | Reduce `optimizer_runs` from 20,000 to 200 | -2,615 | -3,057 |

**Size Impact (v1.0.2 -> v1.1.0):**
| Contract | v1.0.2 (B) | v1.1.0 (B) | Change | % Change |
|----------|-----------|---------------|--------|----------|
| DidManager | 15,159 | 12,102 | -3,057 | -20.2% |
| W3CResolver | 12,846 | 12,846 | 0 | 0% |

**Gas Impact (median values, key functions):**
| Function | Before | After | Delta | % Change |
|----------|--------|-------|-------|----------|
| createDid | 283,522 | 283,711 | +189 | +0.07% |
| createVm | 282,630 | 271,557 | -11,073 | -3.9% |
| deactivateDid | 63,159 | 51,861 | -11,298 | -17.9% |
| updateController | 87,555 | 78,357 | -9,198 | -10.5% |
| updateService | 209,852 | 198,588 | -11,264 | -5.4% |
| reactivateDid | 50,759 | 48,361 | -2,398 | -4.7% |
| validateVm | 35,446 | 35,506 | +60 | +0.17% |
| isVmRelationship | 17,765 | 17,738 | -27 | -0.15% |

**Key Achievements:**
- 20.2% bytecode reduction with net gas improvement across write operations
- `optimizer_runs=200` contributes 85% of size savings with <0.3% gas increase
- Code-level optimizations (steps 1-5) contribute 442 bytes with pure gas improvement
- EIP-170 margin increased from 9,417 to 12,474 bytes (+32.5%)
- All 152 tests passing, coverage >90% maintained on all source contracts

### v1.2.0 Dual-Variant Architecture (February 2026)

The v1.2.0 release introduces the Ethereum-native variant alongside the existing full W3C variant, sharing a common DidManagerBase.

#### v1.2.0 Contract Sizes
```
| Contract             | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|----------------------|------------------|-------------------|--------------------|--------------------|
| DidManager           | 12,138           | 12,166            | 12,438             | 36,986              |
| DidManagerNative     | 10,533           | 10,561            | 14,043             | 38,591              |
| W3CResolver          | 11,169           | 11,920            | 13,407             | 37,232              |
| W3CResolverNative    | 11,709           | 12,460            | 12,867             | 36,692              |
```

**Key Changes:**
1. **DidManagerBase**: Shared abstract base extracted from DidManager (expiration, controllers)
2. **VMStorageNative**: 1-slot per VM (address + relationships + expiration = 32 bytes) + overflow `_publicKeyMultibase` mapping for keyAgreement VMs
3. **DidManagerNative**: 13.2% smaller than DidManager (10,533 vs 12,138 bytes)
4. **W3CResolverNative**: Derives W3C fields at resolution time; reads publicKeyMultibase from storage for keyAgreement VMs
5. **Inheritance Fix**: VMStorage/VMStorageNative no longer inherit DidManagerBase (correct dependency direction)
6. **publicKeyMultibase support**: Native VMs with keyAgreement (0x04) must store a public key; enforced at creation time

**Variant Comparison:**
| Metric | Full W3C (DidManager) | Native (DidManagerNative) | Difference |
|--------|----------------------|--------------------------|------------|
| Runtime Size | 12,138 B | 10,533 B | -13.2% |
| VM Storage | Multi-slot per VM | 1 slot + overflow for keyAgreement | ~80% less |
| Key Types | Any (RSA, Ed25519, secp256k1) | Ethereum secp256k1 only | Trade-off |
| W3C Fields | Stored per VM | Derived at resolution (except publicKeyMultibase for keyAgreement) | Trade-off |

### v1.2.1 isAuthorized() Addition (February 2026)

The v1.2.1 release adds the public `isAuthorized()` function for cross-DID controller-aware authorization and removes the redundant `authenticate()` function.

#### v1.2.1 Contract Sizes
```
| Contract             | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|----------------------|------------------|-------------------|--------------------|--------------------|
| DidManager           | 12,550           | 12,578            | 12,026             | 36,574              |
| DidManagerNative     | 10,944           | 10,972            | 13,632             | 38,180              |
| W3CResolver          | 11,169           | 11,920            | 13,407             | 37,232              |
| W3CResolverNative    | 11,709           | 12,460            | 12,867             | 36,692              |
```

**Key Changes:**
1. **isAuthorized()**: New public view function for cross-DID controller-aware authorization (returns bool instead of reverting)
2. **authenticate() removed**: Was redundant wrapper around `isVmRelationship(0x01)`, replaced by direct `isVmRelationship()` calls
3. **28 new unit tests**: 14 per variant (happy paths, failure paths, input validation)

**Size Impact (v1.2.0 → v1.2.1):**
| Contract | v1.2.0 (B) | v1.2.1 (B) | Change | % Change |
|----------|-----------|-----------|--------|----------|
| DidManager | 12,138 | 12,550 | +412 | +3.4% |
| DidManagerNative | 10,533 | 10,944 | +411 | +3.9% |
| W3CResolver | 11,169 | 11,169 | 0 | 0% |
| W3CResolverNative | 11,709 | 11,709 | 0 | 0% |

**Net size change**: +412/+411 bytes for `isAuthorized()` minus ~30 bytes saved from removing `authenticate()`. The addition provides cross-DID controller-aware authorization that was previously only available internally via `_validateSenderAndTarget()`.

### v1.2.4 Centralized Parameter Validation (March 2026)

The v1.2.4 release extracts 14 duplicated inline parameter validation blocks into 3 reusable `internal pure` functions in `DidManagerBase.sol`.

#### v1.2.4 Contract Sizes
```
| Contract             | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
|----------------------|------------------|-------------------|--------------------|--------------------|
| DidManager           | 12,450           | 12,478            | 12,126             | 36,674              |
| DidManagerNative     | 10,844           | 10,872            | 13,732             | 38,280              |
| W3CResolver          | 11,169           | 11,920            | 13,407             | 37,232              |
| W3CResolverNative    | 11,709           | 12,460            | 12,867             | 36,692              |
```

**Key Changes:**
1. **`_validateTripleParams()`**: Validates methods, senderId, targetId (replaces 8 inline blocks)
2. **`_validateAuthorizedParams()`**: Validates all 6 isAuthorized parameters (replaces 2 inline blocks)
3. **`_validateViewParams()`**: Validates methods, id, sender for view functions (replaces 2 inline blocks)
4. **File-level `MissingRequiredParameter` error**: Added to DidManagerBase.sol for validation helpers

**Size Impact (v1.2.1 → v1.2.4):**
| Contract | v1.2.1 (B) | v1.2.4 (B) | Change | % Change |
|----------|-----------|-----------|--------|----------|
| DidManager | 12,550 | 12,450 | -100 | -0.8% |
| DidManagerNative | 10,944 | 10,844 | -100 | -0.9% |
| W3CResolver | 11,169 | 11,169 | 0 | 0% |
| W3CResolverNative | 11,709 | 11,709 | 0 | 0% |

**Deduplication Summary:**
| Pattern | Before | After | Eliminated |
|---------|--------|-------|-----------|
| Triple-bytes32 (methods+senderId+targetId) | 8 inline blocks | 1 function + 8 calls | 8 blocks |
| Quad (createVm: triple + relationships) | 2 large blocks | 2 calls + 2 residual lines | 2 blocks reduced |
| Six-param (isAuthorized) | 2 large blocks | 1 function + 2 calls | 2 blocks |
| View triple (methods+id+sender) | 2 inline blocks | 1 function + 2 calls | 2 blocks |

**Note:** 4 instances in VMStorage/VMStorageNative left as-is (no shared base between them). All 3 helpers are `internal pure` — zero storage impact, optimizer inlines at `optimizer_runs=200`.

#### Trade-off Analysis

The v1.0 architecture provides:
- **Contract Size Reduction**: W3CResolver reduced by 694 bytes (5.3%)
- **Gas Optimization**: ~98% reduction in resolution gas per VM (no Base58 encoding)
- **Flexible key storage**: Supports RSA-4096 and post-quantum keys (up to 1500 bytes)
- **Storage efficiency**: Dynamic bytes use only needed storage vs fixed arrays
- **Off-chain Encoding**: Callers encode multibase strings (one-time cost)

## Optimization Impact

### Architecture Evolution
1. **v0.1.0-v0.1.4**: Foundation building with gradual size increases
2. **v0.2.0-v0.3.0**: Feature additions causing size growth
3. **v0.4.0-v0.8.0**: Optimization phase with size stabilization

### Gas Efficiency Correlation
The size optimizations directly correlate with:
- Reduced deployment costs (2,803,776 gas for full deployment)
- Lower transaction costs (249,448 gas per DID creation)
- Improved margin safety for contract upgrades

## Research Implications

### Academic Contributions
1. **Full On-chain Storage**: Demonstrates feasibility of complete DID document storage
2. **Size Optimization**: Proves W3C compliance doesn't require excessive contract sizes
3. **Scalability**: Shows stable size growth despite feature additions

### Performance vs. Features Trade-off
- **W3C Compliance**: Maintained throughout all versions
- **Feature Richness**: Enhanced VM types, service endpoints, controller delegation
- **Size Control**: Stable ~12kB range for core contracts

## Technical Details

### Size Calculation Methodology
- **Runtime Size**: Actual deployed bytecode size
- **Initcode Size**: Constructor and initialization code
- **Margin**: Available space before hitting size limits (24,576 bytes)

### Contract Size Limits
- **EIP-170**: Maximum contract size of 24,576 bytes (24.576 kB)
- **Current Utilization**: ~50% of maximum size limit
- **Safety Margin**: >12kB available for future enhancements

### Four-Contract Architecture Benefits
1. **Modular Design**: Separate concerns for size optimization
2. **Inheritance Model**: VMStorage and ServiceStorage as abstract contracts
3. **Gas Efficiency**: Reduced deployment and interaction costs
4. **Maintainability**: Clear separation of functionality

## References

### Data Sources
- Size comparison files: [Before](../assets/data/sizes_before.txt) | [After](../assets/data/sizes_after.txt)
- Visual documentation: [Screenshot Archive](../assets/screenshots/contract-size/)
- Version tracking: Git tags v0.1.0 through v0.8.0

### Related Documentation
- [Gas Consumption History](./gas-consumption-history.md)
- [Test Coverage History](./test-coverage-history.md)
- [Performance Trends Analysis](../analysis/performance-trends.md)

### Academic Context
This size evolution supports the PhD thesis on **"SSIoBC DID Manager: First fully on-chain DID document management system"** by demonstrating controlled growth while maintaining performance and compliance requirements.

---

*Last Updated: v1.2.4 - Centralized parameter validation in DidManagerBase (-100 B each variant)*