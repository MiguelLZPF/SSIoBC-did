# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Table of Contents

- [Unreleased](#unreleased)
- [1.2.0 — 2026-02-15](#120--2026-02-15)
- [1.1.0 — 2026-02-05](#110--2026-02-05)
- [1.0.2 — 2026-02-05](#102--2026-02-05)
- [1.0.1 — 2026-02-03](#101--2026-02-03)
- [0.8.0 — 2024-07-06](#080--2024-07-06)
- [0.6.0 — 2024-04-21](#060--2024-04-21)

## [Unreleased]

### Added

- Open source publication files (LICENSE, CITATION.cff, CONTRIBUTING.md, SECURITY.md, CHANGELOG.md)
- GitHub issue templates

### Changed

- SPDX license identifiers updated from UNLICENSED to Apache-2.0 across all source files

## [1.2.0] — 2026-02-15

### Added

- Ethereum-Native variant (`DidManagerNative`, `VMStorageNative`, `W3CResolverNative`) for single-slot address-based VMs
- `DidManagerBase` shared abstract contract for common DID logic (expiration, controllers)
- `W3CResolverUtils` shared library for resolver field formatting and validation
- `HashUtils` shared library for hash-based storage indexing
- `publicKeyMultibase` support for keyAgreement verification methods in native variant
- E2E integration test for ECDH key exchange via DID
- Unified CI workflow with 6 parallel jobs (build, test, coverage, quality, security, gas-diff)
- Contract size CI check (EIP-170 compliance)

### Changed

- Dual-variant architecture: Full W3C (multi-key, multi-type) and Ethereum-Native (single-key, Ethereum-only)
- `VMStorage` and `VMStorageNative` are pure storage abstracts (no `DidManagerBase` inheritance)
- `optimizer_runs` reduced from 20,000 to 200 for deployment size optimization (-2,615 bytes)
- All `require(string)` replaced with custom errors across all contracts

### Fixed

- CI formatting drift, environment variable failures, and LCOV compatibility
- Comment indentation to match `forge fmt` v1.5.1

## [1.1.0] — 2026-02-05

### Changed

- Optimized `DidManager` bytecode size by 20.2%
- SLOAD caching in `_isExpired` (read storage once into local variable)
- Direct storage reads in `_isControllerFor` loops (avoids memory copy)
- Dead code removal in `_isVmRelationship`

## [1.0.2] — 2026-02-05

### Added

- `reactivateDid` function to restore deactivated DIDs

## [1.0.1] — 2026-02-03

### Added

- W3C-compliant `deactivateDid` functionality
- Comprehensive W3CResolver tests
- Documentation system for PhD research validation
- >90% test coverage enforcement

### Changed

- Replaced `HashBasedList` with `EnumerableSet` in `ServiceStorage` and `VMStorage`
- Consolidated method parameters into single `bytes32` value for DID operations
- Replaced `require` statements with custom errors for gas optimization
- Introduced `IVMStorage` interface
- Optimized `ServiceStorage` with dynamic bytes (96% storage reduction)
- Optimized `VMStorage` with dynamic bytes and `uint88` packing

### Fixed

- W3CResolver import paths standardized to `@src/` remapping
- Authentication bug in DID operations
- Controller removal via `bytes32(0)` in `updateController`

## [0.8.0] — 2024-07-06

### Added

- W3CResolver contract for on-chain DID document resolution
- Service endpoint management with type and endpoint fields
- Verification method relationship bitmask system (authentication, assertion, keyAgreement, capabilityInvocation, capabilityDelegation)
- DID expiration tracking for all write methods

### Changed

- VM and service removal functions added
- Public key format changed to multibase encoding

## [0.6.0] — 2024-04-21

### Added

- Initial `DidManager` contract and `IDidManager` interface
- `VMStorage` contract for verification method management
- `ServiceStorage` contract for service endpoint management
- Basic DID creation and VM creation functionality

[Unreleased]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v0.8.0...v1.0.1
[0.8.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v0.6.0...v0.8.0
[0.6.0]: https://github.com/MiguelLZPF/SSIoBC-did/releases/tag/v0.6.0
