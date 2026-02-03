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

| Version | DidManager | W3CResolver | Architecture Notes |
|---------|------------|-------------|-------------------|
| v0.1.0  | ~10.5 kB   | N/A         | Initial single-contract approach |
| v0.1.2  | ~11.2 kB   | ~9.8 kB     | Separated resolver functionality |
| v0.1.3  | ~11.5 kB   | ~10.1 kB    | Enhanced read functions |
| v0.1.4  | ~11.8 kB   | ~10.5 kB    | Controller system improvements |
| v0.2.0  | ~12.1 kB   | ~11.2 kB    | Service endpoint integration |
| v0.3.0  | ~12.3 kB   | ~11.8 kB    | VM expiration functionality |
| v0.4.0  | ~12.2 kB   | ~12.1 kB    | Service testing optimizations |
| v0.5.0  | ~12.1 kB   | ~12.3 kB    | VM testing enhancements |
| v0.6.0  | ~12.0 kB   | ~12.5 kB    | DidManager test coverage |
| v0.7.0  | ~11.9 kB   | ~12.7 kB    | Performance optimizations |
| v0.8.0  | ~12.0 kB   | ~12.8 kB    | W3C resolver completion |
| v1.0-pre | 14.3 kB     | 13.1 kB     | VMStorage optimization + Base58 |
| v1.0 | 13.9 kB | 12.4 kB | Pre-encoded multibase (Base58 removed) |
| **v1.0.1** | **13.9 kB** | **12.8 kB** | **ServiceStorage optimization (dynamic bytes)** |

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

*Last Updated: v1.0.1 - ServiceStorage optimization (dynamic bytes, 96% per-service storage reduction)*