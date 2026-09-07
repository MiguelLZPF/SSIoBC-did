# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Table of Contents

- [1.6.0 — 2026-09-07](#160--2026-09-07)
- [1.5.0 — 2026-09-06](#150--2026-09-06)
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

## [1.6.0] — 2026-09-07

Toolchain and dependency refresh. No Solidity in `src/` changed, no ABI selector moved, and no
behaviour is different. The deployed bytecode does change, because the compiler changed, which is
why this is a minor bump and not a patch.

### Changed

- **Foundry 1.5.1 -> 1.8.1.** The six containerised CI jobs move from
  `ghcr.io/foundry-rs/foundry@sha256:3a70bfa9…` to `sha256:0c00cb0b…`. Digest read from the ghcr
  manifest for the `v1.8.1` tag; the same query returns the old digest for `v1.5.1`, which matches
  what the file already held.
- **solc 0.8.33 -> 0.8.36**, in `foundry.toml` and in the six fixed pragmas under `script/`.
  `src/` keeps its `>=0.8.0 <0.9.0` range, so the compiler is chosen in one place.
  `evm_version` stays `osaka`: 0.8.36 adds an `amsterdam` target, but that fork is not live and the
  published gas numbers are measured against the fork the contracts will be deployed on.
- **forge-std 1.10.0 -> 1.16.2** and **openzeppelin-contracts 5.5.0 -> 5.7.0**.
- **GitHub Actions**: `actions/checkout` v6.0.3 -> v7.0.1, `actions/cache` (save and restore)
  v5.0.5 -> v6.1.0, `marocchino/sticky-pull-request-comment` v3.0.4 -> v3.0.5. `upload-artifact`
  v7.0.1, `slither-action` v0.4.2, `foundry-gas-diff` v3.21 and `lcov-reporter-action` v0.4.0 are
  already current.
- **pre-commit hooks** `pre-commit/pre-commit-hooks` v4.5.0 -> v6.0.0.
- `docs-lint.yml` pinned `actions/checkout` by floating tag while `ci.yml` pinned every action by
  SHA. Both are now pinned by SHA.
- Contract sizes: DidManager 13,907 B (-24), DidManagerNative 12,294 B (-29), W3CResolver
  11,845 B (unchanged), W3CResolverNative 12,367 B (unchanged). EIP-170 limit is 24,576 B.
- `createDid` gas: 216 less on both variants (median). Nothing moves by 1%.
- Coverage is unchanged at 98.83% lines, 98.86% functions, 94.96% branches.

### Fixed

- `foundry.lock` claimed openzeppelin-contracts v5.4.0 while the recorded gitlink was v5.5.0.
  Commit 91589e8 (2026-02-02) moved the submodule and left the lock behind, so for seven months
  every build compiled against v5.5.0 while the lock said otherwise. Corrected before the bump, in
  its own commit.
- `.github/WORKFLOWS.md` claimed the Slither SARIF is pushed to the GitHub Security tab via
  `codeql-action/upload-sarif@v3`. It is uploaded as a build artifact; the `security` job holds
  `contents: read` and `upload-sarif` needs `security-events: write`.
- Eleven tracked files gained a final newline or lost a trailing blank line, which
  `end-of-file-fixer` had always wanted and only a `--all-files` run surfaced.

### Removed

- `.prettierrc.yaml`. It declared `prettier-plugin-solidity`, but the repository has no
  `package.json` and no npm step, so the plugin could never be installed and the config was never
  read. `forge fmt` is the formatter.

### Notes

- **Test totals changed without a test changing.** Foundry 1.8.1 counts an invariant suite as one
  test where 1.5.1 counted one per `invariant_` function, so the CI scope reports 383 instead of
  396 and the unfiltered scope 397 instead of 410. The same 15 invariants run and pass.
- **`forge lint` reports 479 findings where 1.5.1 reported 48**, from new rule families
  (`calls-loop`, `weak-prng`, `reentrancy-no-eth` and others). It still exits 0, so the `quality`
  job is unaffected, and the three ids in `foundry.toml` `exclude_lints` are still valid. Triaging
  the new rules is separate work.
- **The gas report's Avg column is not comparable across this release.** Forge 1.8.1 reports about
  half the calls per function that 1.5.1 did for the same suite. `docs/metrics/` uses medians for
  the v1.5.0 -> v1.6.0 delta and says so.
- **A pre-existing failure is now recorded, not introduced.**
  `test_GasBenchmark_CreateMultipleServices_ScalingAnalysis` asserts service creation stays under
  200,000 gas and measures 225,926. The identical figure was reproduced on `main` before this
  work, so the `thorough` job that runs `test/performance/` on push to `main` was already red. The
  pull-request gate excludes that path and stays green.
- solc 0.8.36 warns six times that `at` will become a keyword. All six are in
  openzeppelin-contracts `EnumerableSet.sol`, not in this tree.

## [1.5.0] — 2026-09-06

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

- **`onlyDirectEOA` reshaped into a thin modifier over an internal function.** A modifier body is
  inlined at every use site, so the guard existed 10 times in the deployed bytecode. Moving the
  check into `_requireDirectEOA()` saves **158 bytes per manager** and costs ~22 gas per guarded
  call, which is the right side of `optimizer_runs = 200`. Byte-identical to removing the modifier
  entirely, while keeping the precondition visible in each function signature. Same pattern as
  OpenZeppelin `Ownable._checkOwner`. The convention is now recorded in `CLAUDE.md`.

- `IDidAuth` gains `isAuthorizedOffChainWithSigner`; existing selectors are unchanged, so this is
  ABI-additive.
- Contract sizes: DidManager 13,931 B (+790), DidManagerNative 12,323 B (+790), W3CResolver
  11,845 B (+998), W3CResolverNative 12,367 B (+998). EIP-170 limit is 24,576 B. The whole cost of
  the DID-string work sits in the resolvers, on the read path, where nobody pays gas for it.
- `createDid` gas: 277,889 -> 277,915 mean, **+26**. Measured with `forge test --gas-report` against
  the pre-change tree; the write path is untouched.
- 371 tests passing on the default profile (325 before), 410 under the CI profile (363 before).

### Fixed

- **DID-string rendering cleaned up, and the trust boundary made explicit.** The previous fix
  stripped the `;` filler but left three holes, each found independently by two reviewers: segment
  0 was emitted unguarded so an all-filler segment rendered `did::main:<id>`; no character set was
  enforced, so a `:` injected an extra segment, a `#` injected a DID-URL fragment and uppercase
  passed through; and filler was stripped from anywhere in a segment, so `"l;zpf"` and `"lzpf"`
  rendered identically while hashing differently.

  `W3CResolverUtils.trimMethodSegment` now removes a **trailing** filler run only, which fixes the
  ambiguity that strip-anywhere introduced. It rejects nothing else, and neither does `createDid`.

  **None of the seven canonical-`methods` rules is enforced on chain, deliberately.** `id` is
  `keccak256(methods, random, msg.sender, prevrandao)`, so two DIDs cannot be made to render the
  same string without a 256-bit preimage, and the hex `id` follows every segment, so an injected
  `#` cannot make the rendered prefix equal another party's DID. These are conformance defects,
  not attacks, and conformance is the SDK's responsibility. Two enforcing designs were built and
  reverted: validating in `createDid` cost **+13,183 gas (+4.7%)** on every DID, and reverting
  inside `resolve` made the contract withhold data it holds and baked an unamendable format policy
  into a system with no upgrade path. See the new "Validation Scope and Trust Boundary" section of
  `CLAUDE.md`.

- **`W3CResolverBase.checkMethods(bytes32) external pure`** enforces all seven rules for anyone who
  wants them. **Nothing in the contract calls it.** A client invokes it via `eth_call` at zero gas
  before sending a creation transaction. A fuzz test asserts the property that matters: whatever
  the preflight accepts renders a conformant DID string.

- **`HashUtils.packMethods(bytes10,bytes10,bytes10)`** builds a canonical value. Needed because
  `bytes32(bytes10("lzpf"))` pads with `0x00`, which renders but is not canonical; the helper
  converts it to the canonical `;` form. `packMethods(bytes10("lzpf"), bytes10("main"), bytes10(0))` reproduces
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

> Never tagged. This work was committed and released as part of 1.5.0; the section is kept
> because the changes are distinct and worth reading separately.

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

[1.6.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.3.1...v1.5.0
[1.4.0]: https://github.com/MiguelLZPF/SSIoBC-did/commit/9db204fe70fca8803e57ce459465a2a76a4ed120
[1.3.1]: https://github.com/MiguelLZPF/SSIoBC-did/compare/v1.3.0...v1.3.1
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
