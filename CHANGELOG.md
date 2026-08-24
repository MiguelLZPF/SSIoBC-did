# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Table of Contents

- [1.5.0 — 2026-08-24](#150--2026-08-24)
- [1.4.0 — 2026-06-10](#140--2026-06-10)
- [1.3.1 — 2026-03-10](#131--2026-03-10)
- [1.3.0 — 2026-03-08](#130--2026-03-08)
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

## [1.5.0] — 2026-08-24

### Added

- **ERC-1271 contract-signer support in the off-chain authorization path** (roadmap idea #1).
  New view function `isAuthorizedOffChainWithSigner(methods, senderId, senderVmId, targetId, relationship, signer, messageHash, signature)`
  on both variants. A contract signature cannot be recovered, so the caller states the claimed
  `signer` and the contract verifies the claim with OpenZeppelin `SignatureChecker`:
  `ecrecover` when `signer` has no code, an `IERC1271.isValidSignature` staticcall otherwise.
  On the read path this covers **EIP-7702-delegated EOAs** and any contract that both implements
  ERC-1271 and owns an active verification method. Plain smart accounts and multisigs are **not**
  usable yet: a contract cannot activate its own VM (see Notes), so 7702 is the only shape
  reachable today. The `onlyDirectEOA` guard on write paths is untouched.
- `test/mocks/MockERC1271Wallets.sol` — ERC-1271 wallet mocks (approving, rejecting, reverting,
  and a contract with no `isValidSignature`). The approving mock stores its owner in an
  `immutable`, so `vm.etch` preserves it and tests can simulate an EIP-7702 delegated EOA.
- `test/unit/AuthorizeOffChainErc1271.unit.t.sol` — 24 tests (17 full W3C + 7 native): EOA
  parity with the `v,r,s` overload, contract-signer accept/reject, wrong magic value, reverting
  wallet, non-wallet contract, malformed signature, and parameter validation.

### Changed

- `IDidAuth` gains `isAuthorizedOffChainWithSigner`; existing selectors are unchanged, so this is
  ABI-additive.
- Contract sizes: DidManager 14,789 B (+1,648), DidManagerNative 13,181 B (+1,648), W3CResolver
  11,522 B (+675), W3CResolverNative 12,044 B (+675). EIP-170 limit is 24,576 B.
- `createDid` gas: 277,889 -> 291,072 mean, **+13,183 (+4.7%)**, the cost of validating `methods`.
  Measured with `forge test --gas-report` against the pre-change tree. One-time per DID.
- 370 tests passing on the default profile (325 before), 411 under the CI profile (363 before).

### Fixed

- **`methods` is now validated at `createDid`, so a non-conformant DID string cannot be produced.**
  The previous fix stripped the `;` filler but left three holes, each found independently by two
  reviewers: segment 0 was emitted unguarded so an all-filler segment rendered `did::main:<id>`
  with an empty `method-name`; no character set was enforced, so a `:` injected an extra segment,
  a `#` injected a DID-URL fragment that makes a parser read a different base DID, and uppercase
  passed through; and filler was stripped from anywhere in a segment, so `"l;zpf"` and `"lzpf"`
  rendered identically while hashing differently.

  `DidAggregate._validateMethods` now enforces six rules at the one point where `methods` enters
  storage: segment 0 non-empty and `[a-z0-9]`; segments 1 and 2 `[a-zA-Z0-9.-_]`; filler trailing
  only; filler exactly `;` (`METHOD_FILLER`), so `0x00` padding is rejected; segments left-packed;
  and the two tail bytes canonical. Together these make the `bytes32 methods` to DID-string
  mapping **injective**, so a DID string decodes back to exactly one `methods`.

  `W3CResolverUtils.trimMethodSegment` enforces the same rules at render time. That second layer is
  necessary, not belt and braces: `resolve` has no existence check, so a caller can hand it a
  `methods` that was never stored and still get a formatted string back.

  New errors in `DidTypes.sol`: `MethodNameEmpty`, `MethodCharInvalid`, `MethodFillerNotTrailing`,
  `MethodSegmentsNotLeftPacked`, `MethodPaddingMustBeSemicolon`.

- **`HashUtils.packMethods(bytes10,bytes10,bytes10)`** builds a canonical value. Needed because
  `bytes32(bytes10("lzpf"))` pads with `0x00` and is now rejected; the helper converts that to the
  canonical `;` form. `packMethods(bytes10("lzpf"), bytes10("main"), bytes10(0))` reproduces
  `DEFAULT_DID_METHODS` byte for byte, asserted by a test.


- **The emitted DID string was not a valid W3C DID.** `DEFAULT_DID_METHODS` pads its 10-byte
  segments with `;` (`0x3B`), but `W3CResolverUtils.trimBytes` only stripped `0x00`, so the
  filler survived into the output: `did:lzpf;;;;;;:main;;;;;;:;;;;;;;;;;:b3dd18c0…`. W3C DID
  Core v1.0 section 3.1 allows only `a-z` and `0-9` in `method-name`, and `ALPHA / DIGIT /
  "." / "-" / "_" / pct-encoded` in `idchar`, so the string was rejected by any ABNF-based
  parser (`did-resolver`, and therefore Veramo, `did-jwt-vc` and the DIF Universal Resolver)
  before reaching the contract. New `W3CResolverUtils.trimMethodSegment` strips both fillers
  per segment and drops a segment that becomes empty. Default methods now render as
  `did:lzpf:main:<id>`.
- The `;` filler is deliberate and is kept: it makes a deliberately-empty segment
  distinguishable from an unset one, which zero-padding cannot express, and keeps the constant
  readable. The fix is **output-only**: stored `bytes32` values and every `idHash` are
  unchanged, so no existing DID moves.

### Added (conformance)

- `test/unit/DidStringConformance.unit.t.sol` — 10 tests (7 full W3C + 3 native) asserting the
  emitted DID string against the W3C DID Core v1.0 section 3.1 ABNF, across default methods,
  omitted methods, zero-padded methods, one segment, and three segments. Includes a negative
  test proving the checker rejects the pre-fix output, so the assertion is not vacuous.

### Notes

- **EIP-7702 ECDSA fallback.** A delegated EOA carries code, so `SignatureChecker` takes the
  ERC-1271 branch and returns `false` whenever the delegate does not implement
  `isValidSignature`, even for a valid signature from the account's own key. Measured before the
  fallback with `vm.signAndAttachDelegation`: `isAuthorizedOffChain` `true`,
  `isAuthorizedOffChainWithSigner` `false`. The view now recovers directly when the ERC-1271 check
  fails. This grants nothing new: under EIP-7702 the private key keeps full control of the account
  (it can transact directly and re-delegate), so its raw signature is authority the key already
  holds. A signature from any other key is still rejected.
- **Signature malleability differs between the two views.** `isAuthorizedOffChainWithSigner`
  rejects a high-`s` signature (OpenZeppelin `ECDSA`); the raw-`ecrecover`
  `isAuthorizedOffChain` accepts it. Prefer the new view. Locked in by
  `test_WithSigner_Should_ReturnFalse_When_SignatureIsMalleated`.
- **`onlyDirectEOA` proves less than its original NatSpec claimed.** Post-Pectra, `msg.sender ==
  tx.origin` does not imply "no intermediary contract in the call chain": a 7702-delegated EOA has
  code, so a call routed through a permissive delegate still satisfies the equality. What the
  guard still guarantees, and what the authorization model needs, is that the authenticated
  address is exactly the account that signed the transaction. NatSpec, PROJECT.md and the threat
  model now state this limit.
- **ERC-6492 is not supported.** Counterfactual (undeployed) wallets cannot be verified on chain;
  the signing account must already have code.
- **Known gap:** a contract cannot yet *own* a verification method. `createVm` forces
  `expiration = 0` whenever `ethereumAddress` is set, and `validateVm` requires
  `msg.sender == vm.ethereumAddress` under `onlyDirectEOA`, so a contract address can never
  activate its own VM. Contract signers therefore only work for addresses that were validated as
  EOAs and later gained code (the EIP-7702 shape). Closing this needs a signature-based
  `validateVm` and is tracked in `docs/analysis/improvement-roadmap.md`.

## [1.4.0] — 2026-06-10

### ⚠️ BREAKING

- **`createDid` rejects a non-canonical `methods`.** `bytes32(bytes10("name"))`, the natural
  Solidity idiom, pads with `0x00` and now reverts `MethodPaddingMustBeSemicolon()`. Use
  `HashUtils.packMethods`. `DEFAULT_DID_METHODS` is already canonical, so DIDs created with the
  default (or with `methods = 0`) are unaffected and no `idHash` moves.

### ⚠️ BREAKING (1.4.0, never released separately)

- **Authentication identity migrated from `tx.origin` to `msg.sender`** across all write operations:
  - `createDid` (both variants): ID entropy now `keccak256(methods, random, msg.sender, block.prevrandao)`, initial VM `ethereumAddress` and validation now bound to `msg.sender`
  - `reactivateDid` (self-reactivation and controller-reactivation branches) authenticates `msg.sender`
  - `_validateSenderAndTarget` (feeds `expireVm`, `deactivateDid`, `updateController`, `updateService`, `createVm`) authenticates `msg.sender`
- **New `onlyDirectEOA` modifier on all 8 authenticated state-changing entry points per variant** (`createDid`, `createVm`, `validateVm`, `expireVm`, `deactivateDid`, `reactivateDid`, `updateController`, `updateService`): reverts `DirectEOACallRequired()` unless `msg.sender == tx.origin`. Calls routed through intermediary contracts (multisigs, smart accounts, forwarders, ERC-4337 bundlers) now revert — use direct EOA transactions, or `isAuthorizedOffChain` for signature-based flows
- DID IDs created through an intermediary contract pre-1.4.0 are not reproducible with the new derivation (attribution moved from `tx.origin` to `msg.sender`); direct EOA creations are unaffected
- ABI function selectors unchanged; one new custom error added to the ABI

### Security

- **Closes the `tx.origin` confused-deputy/phishing vulnerability class**: previously, any contract a DID owner called could perform DID operations as them (deactivate, rotate controllers, add VMs), because authorization asked "who signed the transaction" instead of "who is calling". With `msg.sender` auth plus the equality guard, the signature-derived identity guarantee is preserved (the guard passes only when `msg.sender` IS the transaction's signing EOA) while intermediary impersonation becomes impossible
- `tx.origin` survives ONLY inside the `onlyDirectEOA` equality guard — never as an identity source
- EIP-7702-delegated EOAs keep working (their own address signs the transaction)

### Added

- `DirectEOACallRequired()` custom error in `src/types/DidTypes.sol`
- `onlyDirectEOA` modifier in `DidAggregate.sol`
- `test/unit/DirectEOAGuard.unit.t.sol` — 20 tests (10 per variant): confused-deputy attack mocks against all 8 guarded entry points, full direct-EOA lifecycle, and msg.sender identity-attribution checks

### Changed

- Rewrote inverted NatSpec on `reactivateDid` (the old comment claimed `tx.origin` *prevented* intermediary impersonation; it enabled it)
- Test helpers (`DidTestHelpers`, `DidTestHelpersNative`) and auth unit tests now prank both `msg.sender` and `tx.origin` to the same EOA
- Contract sizes: DidManager 13,141 B (+256), DidManagerNative 11,533 B (+256), resolvers unchanged
- 363 tests passing under CI profile (343 existing + 20 new guard tests)

## [1.3.1] — 2026-03-10

### Added

- `isAuthorizedOffChain()` view function combining ECDSA signature recovery with authorization checks for gasless DID ownership verification via `eth_call`
- Comprehensive DID lifecycle flows documentation (`docs/analysis/did-lifecycle-flows.md`) covering on-chain auth, off-chain auth, resolution, controller delegation, and operations reference
- 24 unit tests for off-chain authentication (16 Full W3C + 8 Native variants) covering self-controlled/controller-delegated modes, invalid signatures, expired DIDs/VMs, and consistency checks

### Changed

- Extracted `_isAuthorized()` private function from `isAuthorized()` for code reuse (DRY pattern between on-chain and off-chain entry points)
- Added `TEST_PK_1/2/3` private key constants to `Fixtures.sol` for signature-based testing
- Contract sizes: DidManager 12,885 B (+371), DidManagerNative 11,277 B (+371), W3CResolver 10,847 B (unchanged), W3CResolverNative 11,369 B (unchanged)
- 305 tests passing (281 existing + 24 new off-chain auth tests)

## [1.3.0] — 2026-03-08

### Added

- `DidAggregate.sol` — shared abstract aggregate root containing ALL DID lifecycle logic (expiration, controllers, auth, services, parameter validation); eliminates duplication between DidManager and DidManagerNative
- `VMHooks.sol` — tiny shared ancestor declaring 9 abstract VM storage hooks (including `_getVmForAuth`); resolves Solidity diamond inheritance without bytecode overhead
- `W3CResolverBase.sol` — shared abstract base for W3C resolvers (resolve, resolveService)
- ISP-compliant interface segregation: `IDidReadOps`, `IDidWriteOps`, `IDidAuth` composed into `IDidManager`
- `IDidManagerFull.sol` — variant-specific interface extending IDidManager with full W3C VM operations
- Type files in `src/types/`: `DidTypes.sol`, `VmTypes.sol`, `VmTypesNative.sol`, `ServiceTypes.sol`, `W3CTypes.sol`

### Changed

- **Architecture**: Template Method pattern with VMHooks shared ancestor — DidAggregate calls abstract hooks, VMStorage/VMStorageNative provide concrete implementations, no diamond conflict
- `DidManager.sol` rewritten as thin wrapper (~90 lines, was ~315) inheriting VMStorage + DidAggregate
- `DidManagerNative.sol` rewritten as thin wrapper (~100 lines, was ~272) inheriting VMStorageNative + DidAggregate
- `isAuthorized()` extracted from concrete managers into DidAggregate via `_getVmForAuth` hook (eliminates 28 lines of exact duplication)
- `W3CResolver.sol` and `W3CResolverNative.sol` now extend W3CResolverBase
- `_bytesToHexString` changed from `public` to `internal` in W3CResolverBase (fixes _ prefix convention)
- `DEFAULT_CONTEXT` storage variable replaced with in-memory construction (saves ~2100 gas per cold SLOAD)
- `_validateSenderAndTarget` optimized with short-circuit hash on self-operations (saves ~30 gas)
- `W3CDidDocument` struct field order corrected: `capabilityInvocation` now before `capabilityDelegation` (matches W3C spec)
- `NotAControllerforTargetId` renamed to `NotAControllerForTargetId` (casing fix)
- `VmRelationshipOutOfRange` error centralized to `DidTypes.sol` (removed from IVMStorage/IVMStorageNative)
- Storage contracts moved to `src/storage/` (VMStorage, VMStorageNative, ServiceStorage)
- `IDidManager.sol` rewritten as Liskov-safe composite interface (IDidReadOps + IDidWriteOps + IDidAuth)
- Contract sizes: DidManager 12,514 B (+64), DidManagerNative 10,906 B (+62), W3CResolver 10,847 B (-322), W3CResolverNative 11,369 B (-340)
- Function selectors identical (fully backward-compatible ABI)
- 281 tests passing (baseline for v1.3.1 additions)

### Fixed

- Added missing `_validateTripleParams` to `updateService` in DidAggregate (ensures consistent `MissingRequiredParameter` error for zero params)
- Added `checkDidInput` validation to `resolve()` in W3CResolverBase (was missing unlike resolveService/resolveVm)

### Removed

- `DidManagerBase.sol` — fully absorbed into DidAggregate
- `IDidManagerBase.sol` — types extracted to `src/types/DidTypes.sol`, interfaces split into ISP-compliant files

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

[1.3.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.2.4...v1.3.0
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
