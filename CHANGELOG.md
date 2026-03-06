# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Table of Contents

- [1.2.4 — 2026-03-05](#124--2026-03-05)
- [1.2.3 — 2026-02-22](#123--2026-02-22)
- [1.2.2 — 2026-02-19](#122--2026-02-19)
- [1.2.1 — 2026-02-17](#121--2026-02-17)
- [1.2.0 — 2026-02-15](#120--2026-02-15)
- [1.1.0 — 2026-02-05](#110--2026-02-05)
- [1.0.2 — 2026-02-05](#102--2026-02-05)
- [1.0.1 — 2026-02-03](#101--2026-02-03)
- [0.8.0 — 2024-07-06](#080--2024-07-06)
- [0.6.0 — 2024-04-21](#060--2024-04-21)

## [1.2.4] — 2026-03-05

### Changed

- Centralized parameter validation in `DidManagerBase`: 3 new `internal pure` helpers (`_validateTripleParams`, `_validateAuthorizedParams`, `_validateViewParams`) replace 14 inline validation blocks across `DidManager` and `DidManagerNative`
- Extracted shared types, constants, and errors into `IDidManagerBase.sol` interface file (single source of truth)
- Removed duplicate `MissingRequiredParameter` from `IVMStorage` and `IVMStorageNative` interfaces
- Contract sizes reduced: DidManager 12,550 → 12,450 B (-100 B), DidManagerNative 10,944 → 10,844 B (-100 B)
- Fuzz and invariant tests excluded from default `forge test` via `no_match_test` in `foundry.toml`; CI profiles (`ci`, `ci_thorough`) clear the exclusion to run the full suite

## [1.2.3] — 2026-02-22

### Changed

- Standardized 14 import paths from `src/` to `@src/` across 3 source contracts for Foundry remapping compatibility
- Pinned all 9 CI action versions to commit SHA with version comments for supply chain security

### Added

- Open source publication files (LICENSE, CITATION.cff, CONTRIBUTING.md, SECURITY.md, CHANGELOG.md)
- GitHub issue templates

### Changed

- SPDX license identifiers updated from UNLICENSED to Apache-2.0 across all source files

## [1.2.2] — 2026-02-19

### Added

- 11 native fuzz tests (`DidManagerNative.fuzz.t.sol`) covering DID creation, VM relationships, keyAgreement enforcement, expiration, and isAuthorized
- 8 native invariant tests (`NativeSystemInvariants.t.sol`) including publicKeyMultibase-keyAgreement consistency check
- 2 expireVm success-path unit tests (owner + controller scenarios)
- W3CResolver and W3CResolverNative deployment commands in deployment guide

### Fixed

- Critical invariant handler double-create bug in `SystemInvariants.t.sol` — invariants were passing trivially with empty arrays
- Native fuzz test keyAgreement edge case for out-of-range relationship bitmasks
- Deployment guide: corrected native variant script name (`DidManagerNativeScript`)
- Script pragmas aligned to `0.8.33` (was `^0.8.24` across all 6 scripts)
- `.env.example`: HARDFORK corrected to `osaka`, added RPC_URL/PRIVATE_KEY/ETHERSCAN_API_KEY
- `.gitignore`: removed contradictory broadcast rules
- `Configuration.s.sol`: HARDFORK default corrected to `osaka`
- `Helper.sol`: license corrected to Apache-2.0
- `.prettierrc.yaml`: printWidth aligned to 120 (matching foundry.toml)

### Changed

- CI/CD: added SARIF upload step with `security-events: write` permission, upgraded upload-artifact to v6, removed unused env vars
- Test count: 296 → 317 total tests (258 unit, 21 fuzz, 15 invariant, 9 integration, 8 performance, 6 stress)
- Documentation updated across all metrics and analysis files

## [1.2.1] — 2026-02-17

### Added

- `isAuthorized()` public view function for cross-DID controller-aware authorization checks (returns bool, non-reverting)
- 28 new Authorize unit tests (14 per variant) covering self-controlled, controller-delegated, expired, and deactivated scenarios
- `getVmIdAtPosition()` function in `DidManagerNative` for position-based VM ID lookup

### Removed

- `authenticate()` function — was redundant wrapper for `isVmRelationship(0x01)`

### Changed

- `isAuthorized()` uses `_getVm()` instead of `_isVmRelationship()` to avoid `VmAlreadyExpired` revert on expired/missing VMs

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

[1.2.4]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v0.8.0...v1.0.1
[0.8.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v0.6.0...v0.8.0
[0.6.0]: https://github.com/MiguelLZPF/SSIoBC-did/releases/tag/v0.6.0
