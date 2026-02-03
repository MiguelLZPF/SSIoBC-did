# Storage Layout Analysis - SSIoBC DID Manager

## Table of Contents

- [Overview](#overview)
- [Contract Architecture](#contract-architecture)
- [Storage Layout Diagrams](#storage-layout-diagrams)
  - [Overall Architecture](#overall-architecture)
  - [VMStorage Storage (Slots 0-4)](#vmstorage-storage-slots-0-4)
  - [ServiceStorage Storage (Slots 5-7)](#servicestorage-storage-slots-5-7)
  - [DidManager Storage (Slots 8-9)](#didmanager-storage-slots-8-9)
- [Struct Memory Layouts](#struct-memory-layouts)
  - [Controller Struct](#controller-struct)
  - [VerificationMethod Struct](#verificationmethod-struct)
  - [Service Struct](#service-struct)
- [Optimization History](#optimization-history)

---

## Overview

This document provides comprehensive storage layout analysis for the SSIoBC-did smart contract system. Understanding the storage layout is critical for:
- Gas optimization analysis
- Storage cost estimation
- Future upgrade planning
- Academic documentation

**Contract Version:** v1.0.1
**Last Updated:** February 2026

---

## Contract Architecture

The DidManager contract uses inheritance to compose functionality:

```
DidManager IS VMStorage, ServiceStorage
```

Storage slots are allocated in inheritance order:
1. VMStorage slots (0-4)
2. ServiceStorage slots (5-7)
3. DidManager slots (8-9)

---

## Storage Layout Diagrams

### Overall Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                    DidManager Contract Storage Layout (Inheritance Order)              ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║    Inheritance: DidManager IS VMStorage, ServiceStorage                               ║
║    Storage Order: VMStorage slots → ServiceStorage slots → DidManager slots           ║
║                                                                                        ║
║  ┌─────────────────────────────────────────────────────────────────────────────────┐  ║
║  │                      VMStorage State Variables (5 mappings)                      │  ║
║  ├─────────────────────────────────────────────────────────────────────────────────┤  ║
║  │  Slot 0: _vmIds                                                                 │  ║
║  │          mapping(bytes32 didHash => EnumerableSet.Bytes32Set vmIds)             │  ║
║  │          Purpose: O(1) VM ID enumeration per DID                                │  ║
║  │                                                                                 │  ║
║  │  Slot 1: _vmByNsAndId                                                           │  ║
║  │          mapping(bytes32 => mapping(bytes32 vmId => VerificationMethod))        │  ║
║  │          Purpose: Main VM data storage                                          │  ║
║  │                                                                                 │  ║
║  │  Slot 2: _vmIdByPositionHash                                                    │  ║
║  │          mapping(bytes32 positionHash => bytes32 vmId)                          │  ║
║  │          Purpose: Reverse lookup for validateVm()                               │  ║
║  │                                                                                 │  ║
║  │  Slot 3: _didHashByPositionHash                                                 │  ║
║  │          mapping(bytes32 positionHash => bytes32 didHash)                       │  ║
║  │          Purpose: DID recovery from position                                    │  ║
║  │                                                                                 │  ║
║  │  Slot 4: _positionHashByDidAndId                                                │  ║
║  │          mapping(bytes32 => mapping(bytes32 vmId => bytes32 positionHash))      │  ║
║  │          Purpose: Position lookup for cleanup                                   │  ║
║  └─────────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                        ║
║  ┌─────────────────────────────────────────────────────────────────────────────────┐  ║
║  │                   ServiceStorage State Variables (3 mappings)                    │  ║
║  ├─────────────────────────────────────────────────────────────────────────────────┤  ║
║  │  Slot 5: _serviceIds                                                            │  ║
║  │          mapping(bytes32 serviceNs => EnumerableSet.Bytes32Set serviceIds)      │  ║
║  │          Purpose: O(1) service ID enumeration per DID                           │  ║
║  │                                                                                 │  ║
║  │  Slot 6: _serviceByNsAndId                                                      │  ║
║  │          mapping(bytes32 => mapping(bytes32 serviceId => Service))              │  ║
║  │          Purpose: Main service data storage                                     │  ║
║  │                                                                                 │  ║
║  │  Slot 7: _servicePositionByNsAndId                                              │  ║
║  │          mapping(bytes32 => mapping(bytes32 serviceId => uint8 position))       │  ║
║  │          Purpose: Position tracking for events                                  │  ║
║  └─────────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                        ║
║  ┌─────────────────────────────────────────────────────────────────────────────────┐  ║
║  │                    DidManager State Variables (2 mappings)                       │  ║
║  ├─────────────────────────────────────────────────────────────────────────────────┤  ║
║  │  Slot 8: _expirationDate                                                        │  ║
║  │          mapping(bytes32 didHash => uint256 expiration)                         │  ║
║  │          Purpose: DID expiration timestamp (0 = deactivated)                    │  ║
║  │                                                                                 │  ║
║  │  Slot 9: _controllers                                                           │  ║
║  │          mapping(bytes32 didHash => Controller[CONTROLLERS_MAX_LENGTH])         │  ║
║  │          Purpose: Fixed array of 5 controllers per DID                          │  ║
║  └─────────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                        ║
║  TOTAL BASE SLOTS: 10 (mappings only store base slot, data stored at keccak256)       ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

### VMStorage Storage (Slots 0-4)

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                          VMStorage Storage Detail (Slot 0-4)                           ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║  _vmIds (Slot 0) - EnumerableSet Pattern:                                             ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Type: mapping(bytes32 didHash => EnumerableSet.Bytes32Set)                    │   ║
║  │                                                                                │   ║
║  │  EnumerableSet Internal Storage (per didHash):                                 │   ║
║  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   ║
║  │  │  _values: bytes32[] - Stores VM IDs in order                            │   │   ║
║  │  │  _indexes: mapping(bytes32 => uint256) - O(1) index lookup              │   │   ║
║  │  └─────────────────────────────────────────────────────────────────────────┘   │   ║
║  │                                                                                │   ║
║  │  Operations: O(1) add, remove, contains, length, at(index)                     │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  _vmByNsAndId (Slot 1) - Main VM Data:                                                ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Type: mapping(bytes32 didHash => mapping(bytes32 vmId => VerificationMethod)) │   ║
║  │                                                                                │   ║
║  │  Per-VM Storage Layout (VerificationMethod struct):                            │   ║
║  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   ║
║  │  │  Slot N+0:   id (bytes32)                                               │   │   ║
║  │  │  Slot N+1:   type_ (bytes) - dynamic, pointer + data                    │   │   ║
║  │  │  Slot N+2+:  type_ data (variable length)                               │   │   ║
║  │  │  Slot N+?:   publicKeyMultibase (bytes) - dynamic                       │   │   ║
║  │  │  Slot N+?+:  publicKeyMultibase data (variable)                         │   │   ║
║  │  │  Slot N+?:   blockchainAccountId (bytes) - dynamic                      │   │   ║
║  │  │  Slot N+?+:  blockchainAccountId data (variable)                        │   │   ║
║  │  │  Slot N+?:   ethereumAddress(20) + relationships(1) + expiration(11)    │   │   ║
║  │  │              └─────────────PACKED INTO 32 BYTES─────────────────┘       │   │   ║
║  │  └─────────────────────────────────────────────────────────────────────────┘   │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  Position Hash Mappings (Slots 2-4) - Reverse Lookups:                                ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Purpose: Enable validateVm(positionHash) and cleanup operations               │   ║
║  │                                                                                │   ║
║  │  positionHash = keccak256(VM_NAMESPACE, position)                              │   ║
║  │                                                                                │   ║
║  │  _vmIdByPositionHash[positionHash] → vmId                                      │   ║
║  │  _didHashByPositionHash[positionHash] → didHash                                │   ║
║  │  _positionHashByDidAndId[didHash][vmId] → positionHash                         │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

### ServiceStorage Storage (Slots 5-7)

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                  ServiceStorage Storage Detail (Slot 5-7) - v1.0.1 OPTIMIZED          ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║  NOTE: ServiceStorage was OPTIMIZED in v1.0.1 (dynamic bytes, 96% savings)            ║
║                                                                                        ║
║  _serviceIds (Slot 5):                                                                ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Type: mapping(bytes32 serviceNs => EnumerableSet.Bytes32Set)                  │   ║
║  │  serviceNs = keccak256(didHash, SERVICE_NAMESPACE)                             │   ║
║  │  Purpose: O(1) service ID enumeration per DID                                  │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  _serviceByNsAndId (Slot 6) - Optimized in v1.0.1:                                    ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Type: mapping(bytes32 => mapping(bytes32 serviceId => Service))               │   ║
║  │                                                                                │   ║
║  │  Per-Service Storage (v1.0.1 OPTIMIZED):                                       │   ║
║  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   ║
║  │  │  Slot N+0:  id (bytes32)                                                │   │   ║
║  │  │  Slot N+1:  type_.length + offset (dynamic bytes)                       │   │   ║
║  │  │  Slot N+2+: type_.data (packed with '\x00' delimiter)                   │   │   ║
║  │  │  Slot N+?:  serviceEndpoint.length + offset                             │   │   ║
║  │  │  Slot N+?+: serviceEndpoint.data (packed with '\x00' delimiter)         │   │   ║
║  │  │  ─────────────────────────────────────────────────────────────────────  │   │   ║
║  │  │  TYPICAL: 6 slots (vs 161 slots before v1.0.1) = 96% SAVINGS            │   │   ║
║  │  └─────────────────────────────────────────────────────────────────────────┘   │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  _servicePositionByNsAndId (Slot 7):                                                  ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Type: mapping(bytes32 => mapping(bytes32 serviceId => uint8 position))        │   ║
║  │  Purpose: 1-based position tracking for positionHash in events                 │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

### DidManager Storage (Slots 8-9)

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                         DidManager Storage Detail (Slot 8-9)                           ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║  _expirationDate Mapping (Slot 8):                                                    ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Key: didHash = keccak256(methods, id)                                         │   ║
║  │  Value: uint256 expiration timestamp                                           │   ║
║  │                                                                                │   ║
║  │  Storage Location: keccak256(abi.encode(didHash, 8))                           │   ║
║  │                                                                                │   ║
║  │  Values:                                                                       │   ║
║  │  • 0 = Deactivated (permanent, W3C compliant)                                  │   ║
║  │  • 0 < exp < block.timestamp = Expired (reactivatable)                         │   ║
║  │  • exp >= block.timestamp = Active                                             │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  _controllers Mapping (Slot 9):                                                       ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Key: didHash = keccak256(methods, id)                                         │   ║
║  │  Value: Controller[5] fixed array (CONTROLLERS_MAX_LENGTH = 5)                 │   ║
║  │                                                                                │   ║
║  │  Per-DID Storage Layout:                                                       │   ║
║  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   ║
║  │  │  Base: keccak256(abi.encode(didHash, 9))                                │   │   ║
║  │  │                                                                         │   │   ║
║  │  │  Slot Base+0:  Controller[0].id     (bytes32)                           │   │   ║
║  │  │  Slot Base+1:  Controller[0].vmId   (bytes32)                           │   │   ║
║  │  │  Slot Base+2:  Controller[1].id     (bytes32)                           │   │   ║
║  │  │  Slot Base+3:  Controller[1].vmId   (bytes32)                           │   │   ║
║  │  │  Slot Base+4:  Controller[2].id     (bytes32)                           │   │   ║
║  │  │  Slot Base+5:  Controller[2].vmId   (bytes32)                           │   │   ║
║  │  │  Slot Base+6:  Controller[3].id     (bytes32)                           │   │   ║
║  │  │  Slot Base+7:  Controller[3].vmId   (bytes32)                           │   │   ║
║  │  │  Slot Base+8:  Controller[4].id     (bytes32)                           │   │   ║
║  │  │  Slot Base+9:  Controller[4].vmId   (bytes32)                           │   │   ║
║  │  │  ─────────────────────────────────────────────────────────────────────  │   │   ║
║  │  │  TOTAL: 10 SLOTS = 320 BYTES per DID                                    │   │   ║
║  │  └─────────────────────────────────────────────────────────────────────────┘   │   ║
║  │                                                                                │   ║
║  │  Controller Operations (v1.0.1):                                               │   ║
║  │  • Create: Add controller at position (0-4)                                    │   ║
║  │  • Update: Overwrite controller at position                                    │   ║
║  │  • Remove: Set controllerId to bytes32(0)                                      │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

---

## Struct Memory Layouts

### Controller Struct

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                              Controller Struct Layout                                  ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║  struct Controller {                                                                  ║
║    bytes32 id;      // 32 bytes - Controller's DID identifier                         ║
║    bytes32 vmId;    // 32 bytes - (optional) Controller's VM identifier               ║
║  }                                                                                    ║
║                                                                                        ║
║  Memory Layout (64 bytes per Controller):                                             ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Byte 0-31:   id (bytes32)                                                     │   ║
║  │  Byte 32-63:  vmId (bytes32)                                                   │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  Storage for Controller[5] (10 slots = 320 bytes per DID):                            ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Slot 0-1:   Controller[0] (id + vmId)                                         │   ║
║  │  Slot 2-3:   Controller[1] (id + vmId)                                         │   ║
║  │  Slot 4-5:   Controller[2] (id + vmId)                                         │   ║
║  │  Slot 6-7:   Controller[3] (id + vmId)                                         │   ║
║  │  Slot 8-9:   Controller[4] (id + vmId)                                         │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

### VerificationMethod Struct

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                          VerificationMethod Struct Layout                              ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║  struct VerificationMethod {                                                          ║
║    bytes32 id;                    // 32 bytes                                         ║
║    bytes type_;                   // dynamic (max 100 bytes)                          ║
║    bytes publicKeyMultibase;      // dynamic (max 1500 bytes)                         ║
║    bytes blockchainAccountId;     // dynamic (max 200 bytes)                          ║
║    address ethereumAddress;       // 20 bytes ─┐                                      ║
║    bytes1 relationships;          // 1 byte   ├─ PACKED (32 bytes total)             ║
║    uint88 expiration;             // 11 bytes ─┘                                      ║
║  }                                                                                    ║
║                                                                                        ║
║  Storage Layout (per VM):                                                             ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Slot 0:    id (bytes32) - VM identifier like "vm-0"                           │   ║
║  │                                                                                │   ║
║  │  Slot 1:    type_ pointer (bytes)                                              │   ║
║  │  Slot 2+:   type_ data (e.g., "EcdsaSecp256k1VerificationKey2019")             │   ║
║  │                                                                                │   ║
║  │  Slot N:    publicKeyMultibase pointer (bytes)                                 │   ║
║  │  Slot N+1+: publicKeyMultibase data (variable)                                 │   ║
║  │             Typical: 1-3 slots for secp256k1 keys                              │   ║
║  │                                                                                │   ║
║  │  Slot M:    blockchainAccountId pointer (bytes)                                │   ║
║  │  Slot M+1+: blockchainAccountId data (variable)                                │   ║
║  │             Typical: 1-2 slots for CAIP-10 addresses                           │   ║
║  │                                                                                │   ║
║  │  Slot P:    |ethereumAddress(20)|relationships(1)|expiration(11)|              │   ║
║  │             └─────────────PACKED INTO 32 BYTES─────────────────┘               │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  Typical Total: 7-10 slots per VM (depending on key size)                             ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

### Service Struct

```
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                         Service Struct Layout (v1.0.1 OPTIMIZED)                       ║
╠═══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                        ║
║  struct Service {                                                                     ║
║    bytes32 id;              // 32 bytes - Service identifier                          ║
║    bytes type_;             // dynamic (max 500 bytes) - Packed with '\x00'           ║
║    bytes serviceEndpoint;   // dynamic (max 2000 bytes) - Packed with '\x00'          ║
║  }                                                                                    ║
║                                                                                        ║
║  v1.0.1 Storage Layout (per Service):                                                 ║
║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
║  │  Slot 0:   id (bytes32)                                                        │   ║
║  │  Slot 1:   type_ length + pointer                                              │   ║
║  │  Slot 2+:  type_ data (e.g., "LinkedDomains\x00DIDCommMessaging")              │   ║
║  │  Slot N:   serviceEndpoint length + pointer                                    │   ║
║  │  Slot N+1+: serviceEndpoint data (e.g., "https://example.com")                 │   ║
║  │  ─────────────────────────────────────────────────────────────────────────     │   ║
║  │  TYPICAL: 6 slots (vs 161 slots in v1.0) = 96% SAVINGS                         │   ║
║  └────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                        ║
║  ✓ OPTIMIZED in v1.0.1 with dynamic bytes                                            ║
║                                                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
```

---

## Optimization History

| Version | Component | Change | Impact |
|---------|-----------|--------|--------|
| v1.0 | VMStorage | Dynamic bytes for publicKeyMultibase/blockchainAccountId | Flexible key storage |
| v1.0 | VMStorage | Pre-encoded multibase (removed Base58 library) | ~98% resolution gas savings |
| v1.0.1 | ServiceStorage | Dynamic bytes for type_/serviceEndpoint | 96% storage reduction |
| v1.0.1 | DidManager | Controller removal via bytes32(0) | Complete controller lifecycle |

---

*Document generated for SSIoBC-did v1.0.1 - February 2026*
