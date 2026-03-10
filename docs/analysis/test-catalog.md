# Test Catalog — SSIoBC-did Smart Contract Project

> **Complete, exhaustive catalog of every test case in the project.**
> This document must be kept updated whenever tests are added, removed, or modified.

## Table of Contents

- [Summary](#summary)
- [Unit Tests](#unit-tests)
  - [Authorize.unit.t.sol](#1-authorizeunittsol--28-tests)
  - [AuthorizeOffChain.unit.t.sol](#2-authorizeoffchainunittsol--26-tests)
  - [DidManager.unit.t.sol](#3-didmanagerunittsol--60-tests)
  - [DidManagerNative.unit.t.sol](#4-didmanagernativeunittsol--72-tests)
  - [ServiceStorage.unit.t.sol](#5-servicestorageunittsol--19-tests)
  - [VMStorage.unit.t.sol](#6-vmstorageunittsol--30-tests)
  - [W3CResolver.unit.t.sol](#7-w3cresolverunittsol--22-tests)
  - [W3CResolverNative.unit.t.sol](#8-w3cresolvernativeunittsol--27-tests)
- [Fuzz Tests](#fuzz-tests)
  - [DidManager.fuzz.t.sol](#9-didmanagerfuzztsol--10-tests)
  - [DidManagerNative.fuzz.t.sol](#10-didmanagernativefuzztsol--11-tests)
- [Integration Tests](#integration-tests)
  - [DidLifecycle.integration.t.sol](#11-didlifecycleintegrationtsol--6-tests)
  - [KeyAgreementE2E.t.sol](#12-keyagreemente2etsol--3-tests)
- [Invariant Tests](#invariant-tests)
  - [SystemInvariants.t.sol](#13-systeminvariantstsol--7-invariants)
  - [NativeSystemInvariants.t.sol](#14-nativesysteminvariantstsol--8-invariants)
- [Performance Tests](#performance-tests)
  - [GasOptimization.performance.t.sol](#15-gasoptimizationperformancetsol--8-tests)
- [Stress Tests](#stress-tests)
  - [StressTest.t.sol](#16-stresstesttsol--6-tests)
- [Helper & Fixture Files](#helper--fixture-files)
- [Coverage by Production Contract](#coverage-by-production-contract)

---

## Summary

| Category | Count | Files |
|----------|------:|------:|
| Unit Tests | 284 | 8 |
| Fuzz Tests | 21 | 2 |
| Integration Tests | 9 | 2 |
| Invariant Tests | 15 | 2 |
| Performance Tests | 8 | 1 |
| Stress Tests | 6 | 1 |
| **TOTAL** | **343** | **16** |

> **Note**: Unit test count includes both Full W3C and Ethereum-Native variant tests. Many native tests mirror the full variant with additional native-specific cases.

---

## Unit Tests

### 1. `Authorize.unit.t.sol` — 28 tests

**File**: `test/unit/Authorize.unit.t.sol`
**Contracts**: `AuthorizeUnitTest` (14), `AuthorizeNativeUnitTest` (14)
**Primary target**: `DidAggregate.isAuthorized()` — cross-DID controller-aware authorization check (returns bool, non-reverting)

#### AuthorizeUnitTest (Full W3C variant, 14 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_IsAuthorized_Should_ReturnTrue_When_SelfControlledWithAssertionMethod` | Self-controlled DID with assertionMethod VM returns true | `DidAggregate.isAuthorized()` → `_isExpired()` → `_isControllerFor()` → `_getVmForAuth()` → `_isVmRelationship()` | Creates DID + VM with relationship=0x02 (assertion) |
| 2 | `test_IsAuthorized_Should_ReturnTrue_When_ControllerHasAssertionMethod` | Controller-managed DID where controller has assertionMethod returns true | `isAuthorized()` → `_isControllerFor()` (direct storage read of `Controller[5]`) → `_getVmForAuth()` | Creates 2 DIDs, sets controller via `updateController()`, creates VM on controller DID |
| 3 | `test_IsAuthorized_Should_ReturnTrue_When_ControllerWithoutVmRestriction` | Controller without VM restriction (vmId=bytes32(0)) accepts any VM from controller | `isAuthorized()` → `_isControllerFor()` with vmId=0 bypass | `updateController()` with vmId=bytes32(0) |
| 4 | `test_IsAuthorized_Should_ReturnTrue_When_KeyAgreementRelationship` | keyAgreement relationship (0x04) returns true for authorized party | `isAuthorized()` with relationship=0x04 | VM created with keyAgreement flag |
| 5 | `test_IsAuthorized_Should_ReturnFalse_When_VmLacksRequestedRelationship` | VM only has authentication (0x01), asking for assertionMethod (0x02) returns false | `isAuthorized()` → `_getVmForAuth()` → bitmask AND check fails | VM with relationship=0x01, query with 0x02 |
| 6 | `test_IsAuthorized_Should_ReturnFalse_When_ControllerVmLacksRelationship` | Controller has authentication but NOT assertionMethod, returns false | `isAuthorized()` → `_isControllerFor()` ✓ → `_getVmForAuth()` → bitmask fails | Controller VM with auth only, query assertion |
| 7 | `test_IsAuthorized_Should_ReturnFalse_When_SenderIsNotController` | Non-controller caller returns false without reverting | `isAuthorized()` → `_isControllerFor()` returns false (iterates all 5 Controller slots) | No controller relationship established |
| 8 | `test_IsAuthorized_Should_ReturnFalse_When_SenderDidExpired` | Expired sender DID returns false | `isAuthorized()` → `_isExpired()` on sender (caches `_expirationDate[idHash]` into local var) | `vm.warp()` past sender expiration |
| 9 | `test_IsAuthorized_Should_ReturnFalse_When_TargetDidExpired` | Expired target DID returns false | `isAuthorized()` → `_isExpired()` on target | Controller deactivates target DID (owner can't after controllers set) |
| 10 | `test_IsAuthorized_Should_ReturnFalse_When_SenderDidDeactivated` | Deactivated sender DID (expiration=0) returns false | `isAuthorized()` → `_isExpired()` detects exp==0 as deactivated | `deactivateDid()` on sender |
| 11 | `test_IsAuthorized_Should_ReturnFalse_When_SenderVmExpired` | Expired VM on sender returns false | `isAuthorized()` → `_getVmForAuth()` (non-reverting, returns empty for expired VM) | `expireVm()` then check authorization |
| 12 | `test_IsAuthorized_Should_ReturnFalse_When_ControllerUsesWrongVm` | Controller with VM restriction pointing to different VM returns false | `isAuthorized()` → `_isControllerFor()` vmId constraint check | `updateController()` with specific vmId, query with different vmId |
| 13 | `test_RevertWhen_IsAuthorized_WithMissingParameters` | Missing parameters (zero methods, senderId, senderVmId, targetId, relationship, address) revert `MissingRequiredParameter` | `isAuthorized()` → parameter validation in `DidAggregate` | Multiple `vm.expectRevert()` calls, one per parameter |
| 14 | `test_RevertWhen_IsAuthorized_WithInvalidRelationship` | Invalid relationship value (0x20, exceeds 5-bit mask) reverts `VmRelationshipOutOfRange` | `isAuthorized()` → relationship bounds check | relationship=0x20 (bit 6, out of range) |

#### AuthorizeNativeUnitTest (Ethereum-Native variant, 14 tests)

Same 14 test scenarios as `AuthorizeUnitTest` but targeting `DidManagerNative` with 1-slot VM storage (`address(20B) + relationships(1B) + expiration(11B)`). Uses `VMStorageNative._getVmForAuth()` and `VMStorageNative._isVmRelationship()` implementations. Key difference: native VMs are address-based, no `publicKey`/`blockchainAccountId` fields.

---

### 2. `AuthorizeOffChain.unit.t.sol` — 26 tests

**File**: `test/unit/AuthorizeOffChain.unit.t.sol`
**Contracts**: `AuthorizeOffChainUnitTest` (17), `AuthorizeOffChainNativeUnitTest` (9)
**Primary target**: `DidAggregate.isAuthorizedOffChain()` — ECDSA signature-based off-chain authorization

#### AuthorizeOffChainUnitTest (Full W3C variant, 17 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_IsAuthorizedOffChain_Should_ReturnTrue_When_SelfControlledWithAuthentication` | Self-controlled DID with valid ECDSA signature returns true | `DidAggregate.isAuthorizedOffChain()` → `ecrecover(messageHash, v, r, s)` → recovered address matches VM ethereumAddress → `_getVmForAuth()` → `_isVmRelationship()` | `vm.sign(privateKey, messageHash)` to generate v/r/s |
| 2 | `test_IsAuthorizedOffChain_Should_ReturnTrue_When_SelfControlledWithAssertionMethod` | Valid signature with assertionMethod relationship returns true | `isAuthorizedOffChain()` with relationship=0x02 | VM with assertionMethod flag |
| 3 | `test_IsAuthorizedOffChain_Should_ReturnTrue_When_ControllerHasAssertionMethod` | Controller-managed DID with valid controller signature returns true | `isAuthorizedOffChain()` → `_isControllerFor()` → `ecrecover` matches controller VM address | Two DIDs, controller delegation, controller signs |
| 4 | `test_IsAuthorizedOffChain_Should_ReturnTrue_When_ControllerWithoutVmRestriction` | Controller without VM restriction + valid signature returns true | `isAuthorizedOffChain()` → `_isControllerFor()` vmId=0 bypass | Controller with vmId=bytes32(0) |
| 5 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_InvalidSignature` | Garbled v/r/s values return false (ecrecover returns address(0) or wrong address) | `isAuthorizedOffChain()` → `ecrecover` produces wrong address | Manually corrupted signature components |
| 6 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_WrongSigner` | Valid signature from different private key returns false | `isAuthorizedOffChain()` → `ecrecover` produces address that doesn't match any VM | Sign with different key than VM's ethereumAddress |
| 7 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_VmLacksRequestedRelationship` | VM lacks requested relationship, returns false even with valid signature | `isAuthorizedOffChain()` → `_getVmForAuth()` → bitmask AND fails | VM with auth(0x01), query assertion(0x02) |
| 8 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderIsNotController` | Non-controller with valid signature returns false | `isAuthorizedOffChain()` → `_isControllerFor()` returns false | No controller relationship |
| 9 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderDidExpired` | Expired sender DID returns false regardless of valid signature | `isAuthorizedOffChain()` → `_isExpired()` on sender | `vm.warp()` past expiration |
| 10 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_TargetDidExpired` | Expired target DID returns false | `isAuthorizedOffChain()` → `_isExpired()` on target | Target expired via controller deactivation |
| 11 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderDidDeactivated` | Deactivated sender (expiration=0) returns false | `isAuthorizedOffChain()` → `_isExpired()` detects deactivation | `deactivateDid()` on sender |
| 12 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderVmExpired` | Expired VM on sender returns false even with valid signature | `isAuthorizedOffChain()` → `_getVmForAuth()` returns empty | `expireVm()` on sender's VM |
| 13 | `test_IsAuthorizedOffChain_Should_ReturnFalse_When_ControllerUsesWrongVm` | Controller with VM restriction, wrong VM specified returns false | `isAuthorizedOffChain()` → `_isControllerFor()` vmId mismatch | Controller vmId constraint |
| 14 | `test_RevertWhen_IsAuthorizedOffChain_WithMissingParameters` | Missing messageHash, r, s plus inherited params (methods, senderId, etc.) revert `MissingRequiredParameter` | `isAuthorizedOffChain()` → parameter validation | Multiple `vm.expectRevert()` calls |
| 15 | `test_RevertWhen_IsAuthorizedOffChain_WithInvalidRelationship` | Invalid relationship (0x20) reverts `VmRelationshipOutOfRange` | `isAuthorizedOffChain()` → relationship bounds check | relationship=0x20 |
| 16 | `test_IsAuthorizedOffChain_Should_MatchIsAuthorized_When_ValidSignature` | Off-chain result matches on-chain `isAuthorized()` for valid signature | `isAuthorizedOffChain()` result == `isAuthorized()` result | Side-by-side comparison |
| 17 | `testFuzz_IsAuthorizedOffChain_ShouldMatchIsAuthorized` | **Fuzz**: off-chain matches on-chain for any valid privateKey + messageHash combination | `isAuthorizedOffChain()` vs `isAuthorized()`, `vm.sign(fuzzedPK, fuzzedMsg)` | Bounded PK to valid secp256k1 range |

#### AuthorizeOffChainNativeUnitTest (Ethereum-Native variant, 9 tests)

Subset of full variant tests adapted for `DidManagerNative`. Tests 1-5 (true/false basic cases), test 14 (missing params), test 15 (invalid relationship), test 16 (match on-chain), test 17 (fuzz match). Native uses 1-slot VM with address directly in packed storage.

---

### 3. `DidManager.unit.t.sol` — 60 tests

**File**: `test/unit/DidManager.unit.t.sol`
**Contract**: `DidManagerUnitTest`
**Primary targets**: `DidManager.createDid()`, `DidManager.createVm()`, `DidAggregate.deactivateDid()`, `DidAggregate.reactivateDid()`, `DidAggregate.updateController()`, `DidAggregate.expireVm()`

#### DID Creation (4 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_CreateDid_Should_CreateWithDefaultMethods_When_EmptyMethodsProvided` | Empty methods parameter defaults to `DEFAULT_DID_METHODS` constant | `DidManager.createDid()` → `DidAggregate._createDidInternal()` → `HashUtils.calculateIdHash(methods, id)` → stores `_expirationDate[idHash]` | methods=bytes32(0) |
| 2 | `test_CreateDid_Should_CreateWithCustomMethods_When_CustomMethodsProvided` | Custom methods preserved in storage, reflected in hash | `createDid()` → `_createDidInternal()` → `HashUtils.calculateIdHash()` with custom methods | Custom bytes32 methods value |
| 3 | `test_RevertWhen_CreateDid_WithEmptyRandom` | Empty random value reverts with `MissingRequiredParameter` | `createDid()` → parameter validation | random=bytes32(0) |
| 4 | `test_RevertWhen_CreateDid_WithDuplicateDidAlreadyExists` | Creating DID with same inputs twice reverts `DidAlreadyExists` | `createDid()` x2 → `_expirationDate[idHash] != 0` check | Same random value twice |

#### VM Creation & Validation (6 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 5 | `test_CreateVm_Should_CreateVerificationMethod_When_ValidParametersProvided` | VM created with all fields stored correctly | `DidManager.createVm()` → `VMStorage._createVmInternal()` → `HashUtils.calculatePositionHash()` → `EnumerableSet.add()` | Standard VM params from `SharedTest` |
| 6 | `test_RevertWhen_CreateVm_WithEmptyMethods` | Empty methods reverts `MissingRequiredParameter` | `createVm()` → validation | methods=bytes32(0) |
| 7 | `test_RevertWhen_CreateVm_WithEmptyRelationships` | Empty relationships reverts `MissingRequiredParameter` | `createVm()` → validation | relationships=0 |
| 8 | `test_CreateVm_Should_RevertWithDidExpired_When_SenderDidIsExpired` | Expired sender DID prevents VM creation | `createVm()` → `_isExpired()` on sender | `vm.warp()` past sender expiration |
| 9 | `test_CreateVm_Should_RevertWithNotAuthenticated_When_SenderNotAuthenticated` | Unauthenticated sender (wrong address) reverts `NotAuthenticated` | `createVm()` → `_isAuthenticated()` → `_isVmOwner()` fails | `vm.prank(wrongAddress)` |
| 10 | `test_CreateVm_Should_RevertWithDidExpired_When_TargetDidIsExpired` | Expired target DID prevents VM creation | `createVm()` → `_isExpired()` on target | `vm.warp()` past target expiration |

#### Authentication (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 11 | `test_Authenticate_Should_ReturnTrue_When_ValidVmProvided` | Valid VM with correct sender authenticates successfully | `DidAggregate._isAuthenticated()` → `_isVmOwner()` (checks VM ethereumAddress == msg.sender) → `_isVmRelationship()` with auth(0x01) | `vm.prank(vmOwner)` |
| 12 | `test_Authenticate_Should_RevertWithVmAlreadyExpired_When_NonExistentVmProvided` | Non-existent VM reverts `VmAlreadyExpired` (expiration=0 treated as expired) | `_isAuthenticated()` → `_isVmRelationship()` → `_vmExpiration[posHash]` == 0 → revert | Random non-existent vmId |

#### Relationship (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 13 | `test_IsVmRelationship_Should_ReturnTrue_When_ValidRelationshipExists` | Valid relationship bitmask AND returns true | `VMStorage._isVmRelationship()` → loads `_vmRelationships[posHash]` → `stored & requested != 0` | VM with specific relationship |
| 14 | `test_IsVmRelationship_Should_ReturnFalse_When_RelationshipDoesNotExist` | Non-matching bitmask returns false | `_isVmRelationship()` → bitmask AND == 0 | Query relationship not in VM |

#### Expiration (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 15 | `test_GetExpiration_Should_ReturnCorrectTimestamp_When_DidExists` | Returns correct expiration timestamp from storage | `DidAggregate.getExpiration()` → `_expirationDate[idHash]` | Created DID with known expiration |
| 16 | `test_GetExpiration_Should_ReturnZero_When_DidDoesNotExist` | Returns zero for non-existent DID | `getExpiration()` → `_expirationDate[idHash]` == 0 | Random non-existent DID hash |

#### Controller (4 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 17 | `test_UpdateController_Should_SetController_When_ValidParametersProvided` | Controller set successfully in `_controllers[idHash][position]` | `DidAggregate.updateController()` → validates auth → stores `Controller` struct (methods, id, vmId) | Authenticated owner, valid controller params |
| 18 | `test_RevertWhen_UpdateController_WithInvalidSender` | Invalid sender reverts `NotAuthenticated` | `updateController()` → `_isAuthenticated()` fails | `vm.prank(wrongAddress)` |
| 19 | `test_UpdateController_Should_RemoveController_When_ControllerIdIsZero` | Zero controllerId removes controller at position | `updateController()` with controllerId=bytes32(0) → deletes `Controller` struct | Previously set controller |
| 20 | `test_UpdateController_Should_UseLastPosition_When_PositionExceedsMax` | Position > `CONTROLLERS_MAX_LENGTH` clamped to last position | `updateController()` → `position >= CONTROLLERS_MAX_LENGTH ? CONTROLLERS_MAX_LENGTH - 1 : position` | position=255 |

#### Deactivation (12 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 21 | `test_DeactivateDid_Should_SetExpirationToZero_When_ValidParametersProvided` | Expiration set to 0 (deactivated state) | `DidAggregate.deactivateDid()` → `_expirationDate[idHash] = 0` | Authenticated owner |
| 22 | `test_DeactivateDid_Should_AllowControllerToDeactivate_When_ControllerIsSet` | Controller can deactivate managed DID | `deactivateDid()` → `_isControllerFor()` succeeds → sets exp=0 | Controller set via `updateController()` |
| 23 | `test_DeactivateDid_Should_AllowOwnerToDeactivate_When_NoControllersSet` | Owner deactivates own DID when no controllers exist | `deactivateDid()` → `_isAuthenticated()` (no controllers = owner auth) | No controllers set |
| 24 | `test_DeactivateDid_Should_PreventFutureModifications_When_Deactivated` | Deactivated DID prevents createVm, updateService, etc. | `deactivateDid()` then `createVm()` → reverts `DidExpired` | Deactivated DID |
| 25 | `test_DeactivateDid_Should_FailAuthentication_When_Deactivated` | Deactivated DID fails auth check | `deactivateDid()` → `_isExpired()` returns true for exp==0 | Deactivated DID |
| 26 | `test_RevertWhen_DeactivateDid_WithEmptyMethods` | Empty methods reverts `MissingRequiredParameter` | `deactivateDid()` → validation | methods=bytes32(0) |
| 27 | `test_RevertWhen_DeactivateDid_WithEmptySenderId` | Empty sender ID reverts | `deactivateDid()` → validation | senderId=bytes32(0) |
| 28 | `test_RevertWhen_DeactivateDid_WithEmptyTargetId` | Empty target ID reverts | `deactivateDid()` → validation | targetId=bytes32(0) |
| 29 | `test_RevertWhen_DeactivateDid_WithExpiredSenderDid` | Expired sender DID reverts `DidExpired` | `deactivateDid()` → `_isExpired()` on sender | `vm.warp()` past sender expiration |
| 30 | `test_RevertWhen_DeactivateDid_WithUnauthorizedSender` | Unauthorized sender reverts `NotAuthenticated` | `deactivateDid()` → `_isAuthenticated()` | `vm.prank(wrongAddress)` |
| 31 | `test_RevertWhen_DeactivateDid_WithAlreadyDeactivatedTargetDid` | Already deactivated target reverts `DidNotDeactivated` | `deactivateDid()` x2 → second call checks exp==0 | Deactivate twice |
| 32 | `test_RevertWhen_DeactivateDid_WithNonController` | Non-controller trying to deactivate reverts | `deactivateDid()` → `_isControllerFor()` returns false | Controllers set, sender is not one |

#### Reactivation (12 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 33 | `test_ReactivateDid_Should_ReactivateOwnDid_When_OwnerSelfReactivates` | Owner self-reactivates (sender==target path uses `_isVmOwner`, skips DID expiration check) | `DidAggregate.reactivateDid()` → self-reactivation path → `_isVmOwner()` | `deactivateDid()` first, then `reactivateDid()` with sender==target |
| 34 | `test_ReactivateDid_Should_AllowControllerToReactivate_When_ControllerIsActive` | Controller reactivates target (requires active sender DID) | `reactivateDid()` → `_isExpired()` on sender + `_isAuthenticated()` + `_isControllerFor()` | Controller with active DID |
| 35 | `test_ReactivateDid_Should_AllowOperations_When_Reactivated` | Operations (createVm, etc.) work after reactivation | `reactivateDid()` then `createVm()` succeeds | Full deactivate→reactivate cycle |
| 36 | `test_ReactivateDid_Should_PreserveVmsAndServices_When_Reactivated` | VMs and services preserved through deactivation/reactivation | `reactivateDid()` → `getVm()`, `getService()` return same data | Create VMs+services, deactivate, reactivate, verify |
| 37 | `test_ReactivateDid_Should_PreserveControllers_When_Reactivated` | Controllers preserved through cycle | `reactivateDid()` → `_isControllerFor()` still returns true | Set controllers, deactivate, reactivate, verify |
| 38 | `test_RevertWhen_ReactivateDid_WithActiveDid` | Already active DID reverts (can't reactivate non-deactivated) | `reactivateDid()` → checks exp==0 | Active DID (never deactivated) |
| 39 | `test_RevertWhen_ReactivateDid_WithExpiredSenderDid` | Expired sender DID reverts (controller path requires active sender) | `reactivateDid()` → `_isExpired()` on sender | `vm.warp()` past sender expiration |
| 40 | `test_RevertWhen_ReactivateDid_WithInvalidVm` | Invalid VM reverts (self-reactivation requires valid VM) | `reactivateDid()` → `_isVmOwner()` fails | Non-existent vmId |
| 41 | `test_RevertWhen_ReactivateDid_WithNonController` | Non-controller reverts | `reactivateDid()` → `_isControllerFor()` returns false | Controllers set, sender is not one |
| 42 | `test_RevertWhen_ReactivateDid_WithEmptyMethods` | Empty methods reverts `MissingRequiredParameter` | `reactivateDid()` → validation | methods=bytes32(0) |
| 43 | `test_RevertWhen_ReactivateDid_WithEmptySenderId` | Empty sender ID reverts | validation | senderId=bytes32(0) |
| 44 | `test_RevertWhen_ReactivateDid_WithEmptyTargetId` | Empty target ID reverts | validation | targetId=bytes32(0) |

#### VM Expiration (6 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 45 | `test_ExpireVm_Should_RevertWithMissingParameter_When_MethodsIsZero` | Zero methods reverts `MissingRequiredParameter` | `DidAggregate.expireVm()` → validation | methods=bytes32(0) |
| 46 | `test_ExpireVm_Should_RevertWithMissingParameter_When_SenderIdIsZero` | Zero sender ID reverts | `expireVm()` → validation | senderId=bytes32(0) |
| 47 | `test_ExpireVm_Should_RevertWithMissingParameter_When_TargetIdIsZero` | Zero target ID reverts | `expireVm()` → validation | targetId=bytes32(0) |
| 48 | `test_ExpireVm_Should_ExpireSuccessfully_When_OwnerExpiresOwnVm` | Owner sets VM expiration to `block.timestamp` | `expireVm()` → `_isAuthenticated()` → `_expireVmInternal()` → `_vmExpiration[posHash] = block.timestamp` | Authenticated owner |
| 49 | `test_ExpireVm_Should_Succeed_When_ControllerExpiresTargetVm` | Controller can expire VM on managed DID | `expireVm()` → `_isControllerFor()` → `_expireVmInternal()` | Controller delegation setup |
| 50 | `test_RevertWhen_ExpireVm_AlreadyExpired` | Already expired VM reverts `VmAlreadyExpired` | `expireVm()` → `_expireVmInternal()` → checks `_vmExpiration[posHash] <= block.timestamp` | `vm.warp()` past VM expiration or expire twice |

#### Complex Scenarios (6 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 51 | `test_CreateVm_Should_RevertWithNotAControllerForTargetId_When_SenderNotController` | Non-controller creating VM for different DID reverts `NotAControllerForTargetId` | `createVm()` → sender≠target → `_isControllerFor()` returns false → revert | Two DIDs, no controller relationship |
| 52 | `test_ControllerValidation_Should_MatchController_When_NoVmIdRequired` | Controller without vmId constraint validates correctly | `_isControllerFor()` → iterates `Controller[5]` slots → matches methods+id, vmId=0 accepts any | `updateController()` with vmId=bytes32(0) |
| 53 | `test_ControllerValidation_Should_MatchSpecificVmId_When_VmIdConstraintSet` | Controller with specific vmId constraint validates only that VM | `_isControllerFor()` → matches methods+id+vmId | `updateController()` with specific vmId |
| 54 | `test_IsControllerFor_Should_ReturnFalse_When_ControllerNotInList` | Non-controller returns false (iterates all 5 slots, none match) | `_isControllerFor()` → direct storage read (no memory copy) → early return false | Random address not in controller list |
| 55 | `test_IsVmRelationship_Should_HandleAllRelationshipCombinations_When_MultipleSet` | All 5 relationship flags (0x1F bitmask) tested individually | `_isVmRelationship()` with each flag: 0x01(auth), 0x02(assertion), 0x04(keyAgreement), 0x08(capInvocation), 0x10(capDelegation) | VM with relationships=0x1F |
| 56 | `test_GetServiceListLength_Should_BeZero_When_AllServicesRemoved` | Service list length returns 0 after all services deleted | `ServiceStorage.getServiceListLength()` → `EnumerableSet.length()` | Create services, delete all, verify count |

#### Data Cleanup (4 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 57 | `test_CreateDid_Should_TriggerCleanupLoops_When_DataExists` | Hash collision scenario triggers `_removeAllVms()` + `_removeAllServices()` cleanup | `createDid()` → `_createDidInternal()` → cleanup loops → `EnumerableSet.remove()` in while loop | Pre-existing data at hash |
| 58 | `test_RemoveAllFunctions_Should_HandleEmptyState_When_NoDataExists` | Cleanup on empty state is safe (while loops exit immediately) | `_removeAllVms()`, `_removeAllServices()` with empty sets | No prior data |
| 59 | `test_CreateDidWithExistingData_Should_RemoveAllPreviousData_When_HashCollides` | Hash collision removes all old VMs, services, controllers | `createDid()` → full cleanup → `_removeAllVms()`, `_removeAllServices()`, controller reset | Forced hash collision scenario |
| 60 | `test_RemoveAllServices_Should_ExecuteWhileLoop_When_ServicesExist` | Service removal while loop body executes for each service | `_removeAllServices()` → `EnumerableSet.length()` > 0 → `remove()` → repeat | Multiple services pre-created |

---

### 4. `DidManagerNative.unit.t.sol` — 72 tests

**File**: `test/unit/DidManagerNative.unit.t.sol`
**Contract**: `DidManagerNativeUnitTest`
**Primary targets**: `DidManagerNative.createDid()`, `DidManagerNative.createVm()`, `DidAggregate.deactivateDid()`, `DidAggregate.reactivateDid()`, `DidAggregate.updateController()`, `DidAggregate.expireVm()`, `DidManagerNative.getVmPublicKeyMultibase()`, `DidManagerNative.getVmIdAtPosition()`

Contains all 60 tests from `DidManager.unit.t.sol` adapted for native variant (1-slot VM storage: `address(20B) + relationships(1B) + expiration(11B)` + overflow mapping for publicKeyMultibase), **plus** 12 native-specific tests:

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 61 | `test_CreateVm_Should_RevertWithEthereumAddressRequired_When_AddressIsZero` | Native variant requires Ethereum address (mandatory, unlike full W3C) | `VMStorageNative._createVmInternal()` → `EthereumAddressRequired` error | ethereumAddress=address(0) |
| 62 | `test_CreateVm_Should_StorePublicKeyMultibase_When_KeyAgreementWithValidKey` | keyAgreement VMs store publicKeyMultibase in overflow mapping | `_createVmInternal()` → `_publicKeyMultibase[posHash] = publicKey` | relationship includes 0x04, valid 'z'-prefixed key |
| 63 | `test_CreateVm_Should_RevertWithPublicKeyRequired_When_KeyAgreementWithoutKey` | keyAgreement without publicKeyMultibase reverts `PublicKeyRequired` | `_createVmInternal()` → validation | relationship=0x04, empty publicKey |
| 64 | `test_CreateVm_Should_RevertWithNotAllowed_When_PublicKeyWithoutKeyAgreement` | publicKeyMultibase only allowed with keyAgreement flag | `_createVmInternal()` → `NotAllowed` error | publicKey provided but no 0x04 flag |
| 65 | `test_CreateVm_Should_RevertWithInvalidPrefix_When_KeyDoesNotStartWithZ` | Public key must start with 'z' (multibase encoding prefix) | `_createVmInternal()` → `InvalidPrefix` error | publicKey starting with other char |
| 66 | `test_CreateVm_Should_RevertWithPublicKeyTooLarge_When_KeyExceedsMaxLength` | Public key exceeding `MAX_PUBLIC_KEY_LENGTH` reverts | `_createVmInternal()` → `PublicKeyTooLarge` error | Oversized publicKey bytes |
| 67 | `test_GetVmPublicKeyMultibase_Should_ReturnEmpty_When_NonKeyAgreementVm` | Non-keyAgreement VMs return empty publicKeyMultibase | `DidManagerNative.getVmPublicKeyMultibase()` → `_publicKeyMultibase[posHash]` is empty | VM without 0x04 flag |
| 68 | `test_CreateDid_Should_CleanupPublicKeyMultibase_When_ReCreatingDid` | DID recreation cleans up publicKeyMultibase overflow storage | `createDid()` → `_removeAllVms()` → deletes `_publicKeyMultibase[posHash]` | keyAgreement VM exists, then recreate DID |
| 69 | `test_CreateVm_Should_AcceptKeyAgreementOnly_When_NoAuthRelationship` | keyAgreement can exist without authentication flag | `_createVmInternal()` with relationships=0x04 only | No auth(0x01) flag |
| 70 | `test_GetVmIdAtPosition_Should_ReturnCorrectId_When_ValidPositionProvided` | Returns correct VM ID at enumerated position | `DidManagerNative.getVmIdAtPosition()` → `EnumerableSet.at(position)` | Multiple VMs created |
| 71 | `test_GetVmIdAtPosition_Should_ReturnZero_When_InvalidPositionProvided` | Invalid position returns bytes32(0) | `getVmIdAtPosition()` → bounds check | Out-of-bounds position |
| 72 | `test_ControllerDelegation_Should_AllowControllerToModifyTarget_When_ControllerIsSet` | Controller can create VMs on managed target DID | `updateController()` on target → `createVm()` with sender=controller, target=managedDid | Cross-DID delegation |

---

### 5. `ServiceStorage.unit.t.sol` — 19 tests

**File**: `test/unit/ServiceStorage.unit.t.sol`
**Contract**: `ServiceStorageUnitTest`
**Primary targets**: `ServiceStorage.updateService()`, `ServiceStorage.getService()`, `ServiceStorage.getServiceListLength()`

#### Service Creation (3 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_UpdateService_Should_CreateService_When_ValidParametersProvided` | Service created and stored with correct hash | `ServiceStorage.updateService()` → `HashUtils.calculatePositionHash(idHash, serviceId)` → `EnumerableSet.add(posHash)` → stores packed `type_` + `endpoint` | Standard service params |
| 2 | `test_UpdateService_Should_UpdateExistingService_When_ServiceExists` | Existing service updated in-place (same posHash) | `updateService()` → `EnumerableSet.contains()` returns true → overwrites `_serviceType` + `_serviceEndpoint` | Update existing service |
| 3 | `test_UpdateService_Should_CreateMultipleServices_When_DifferentIdsProvided` | Multiple services with different IDs coexist | `updateService()` x N → different `calculatePositionHash()` results | Multiple service IDs |

#### Service Deletion (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 4 | `test_UpdateService_Should_DeleteService_When_EmptyTypeAndEndpointProvided` | Empty type + endpoint triggers deletion | `updateService()` → both empty → `EnumerableSet.remove(posHash)` → deletes storage | Existing service, then update with empty strings |
| 5 | `test_UpdateService_Should_HandleMultipleServiceDeletion_When_ServicesExist` | Multiple services deleted correctly | `updateService()` deletion x N → set shrinks | Delete services one by one |

#### Service Retrieval (4 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 6 | `test_GetService_Should_ReturnCorrectService_When_ValidIdProvided` | Get service by serviceId | `ServiceStorage.getService()` → `calculatePositionHash()` → reads `_serviceType` + `_serviceEndpoint` | Known service ID |
| 7 | `test_GetService_Should_ReturnCorrectService_When_ValidPositionProvided` | Get service by enumerated position | `getService()` → `EnumerableSet.at(position)` → reads storage | Position index |
| 8 | `test_GetService_Should_ReturnEmptyService_When_InvalidPositionProvided` | Invalid position returns empty service struct | `getService()` → position >= `EnumerableSet.length()` → empty return | Out-of-bounds position |
| 9 | `test_GetService_Should_ReturnEmptyService_When_NonExistentIdProvided` | Non-existent ID returns empty | `getService()` → `calculatePositionHash()` → empty storage | Random service ID |

#### Service List Length (3 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 10 | `test_GetServiceListLength_Should_ReturnCorrectCount_When_ServicesExist` | Returns correct count | `ServiceStorage.getServiceListLength()` → `EnumerableSet.length()` | Multiple services |
| 11 | `test_GetServiceListLength_Should_ReturnZero_When_DidDoesNotExist` | Zero for non-existent DID | `getServiceListLength()` → empty set | Non-existent DID hash |
| 12 | `test_GetServiceListLength_Should_DecreaseAfterDeletion_When_ServiceDeleted` | Count decreases after deletion | `getServiceListLength()` before and after `updateService()` deletion | Delete one service |

#### Error & Edge Cases (5 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 13 | `test_RevertWhen_UpdateService_WithEmptyServiceId` | Empty service ID reverts `MissingRequiredParameter` | `updateService()` → validation | serviceId=bytes32(0) |
| 14 | `test_RevertWhen_UpdateService_WithEmptyServiceType` | Empty type (with non-empty endpoint) reverts | `updateService()` → validation | type_="" with endpoint set |
| 15 | `test_RevertWhen_UpdateService_WithEmptyServiceEndpoint` | Empty endpoint (with non-empty type) reverts | `updateService()` → validation | endpoint="" with type_ set |
| 16 | `test_RevertWhen_UpdateService_WithTypeTooLarge` | Type exceeding `MAX_SERVICE_TYPE_LENGTH` reverts `ServiceTypeTooLarge` | `updateService()` → length check | Oversized type_ bytes |
| 17 | `test_RevertWhen_UpdateService_WithEndpointTooLarge` | Endpoint exceeding `MAX_SERVICE_ENDPOINT_LENGTH` reverts `ServiceEndpointTooLarge` | `updateService()` → length check | Oversized endpoint bytes |

#### Complex Scenarios (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 18 | `test_UpdateService_Should_HandleMultipleTypesAndEndpoints_When_PackedWithDelimiter` | Packed delimiter (`;`) separates multiple types/endpoints | `updateService()` → stores packed string → `W3CResolverUtils.parsePackedStrings()` parses at resolution | Delimiter-packed values |
| 19 | `test_UpdateService_Should_AcceptMaxSizeTypeAndEndpoint` | Maximum allowed size type + endpoint accepted | `updateService()` → exactly `MAX_SERVICE_TYPE_LENGTH` + `MAX_SERVICE_ENDPOINT_LENGTH` | Boundary values |

---

### 6. `VMStorage.unit.t.sol` — 30 tests

**File**: `test/unit/VMStorage.unit.t.sol`
**Contract**: `VMStorageUnitTest`
**Primary targets**: `VMStorage._createVmInternal()`, `VMStorage.validateVm()`, `VMStorage._expireVmInternal()`, `VMStorage._isVmRelationship()`, `VMStorage._removeAllVms()`

#### VM Creation (6 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_CreateVm_Should_CreateWithCorrectIdHash_When_ValidParametersProvided` | VM created with correct position hash | `VMStorage._createVmInternal()` → `HashUtils.calculatePositionHash(idHash, vmId)` → stores all VM fields | Standard params |
| 2 | `test_CreateVm_Should_UseDefaultId_When_EmptyIdProvided` | Empty vmId defaults to `DEFAULT_VM_ID` | `_createVmInternal()` → vmId=bytes32(0) → uses `DEFAULT_VM_ID` | vmId=bytes32(0) |
| 3 | `test_CreateVm_Should_SetCorrectExpiration_When_EthereumAddressProvided` | Ethereum address presence sets expiration to pending validation | `_createVmInternal()` → `_vmExpiration[posHash]` set | ethereumAddress != address(0) |
| 4 | `test_CreateVm_Should_SetDefaultExpiration_When_NoEthereumAddress` | No address → default expiration (far future) | `_createVmInternal()` → `DEFAULT_DID_EXPIRATION` | ethereumAddress=address(0) |
| 5 | `test_RevertWhen_CreateVm_WithoutPublicKeyOrBlockchainAccountOrAddress` | Missing all key material reverts `MissingKeyMaterial` | `_createVmInternal()` → no publicKey, no blockchainAccountId, no ethereumAddress | All key fields empty |
| 6 | `test_RevertWhen_CreateVm_WithDuplicateVmId` | Duplicate VM ID reverts `VmAlreadyExists` | `_createVmInternal()` → `EnumerableSet.add()` returns false | Same vmId twice |

#### VM Validation (4 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 7 | `test_ValidateVm_Should_SetExpiration_When_ValidPositionHashProvided` | Validation sets final expiration (proves ownership of ethereumAddress) | `VMStorage.validateVm()` → verifies `msg.sender == _vmEthereumAddress[posHash]` → sets `_vmExpiration[posHash]` | `vm.prank(vmEthereumAddress)` |
| 8 | `test_ValidateVm_Should_UseCustomExpiration_When_ExpirationProvided` | Custom expiration honored during validation | `validateVm()` → custom expiration value | expiration parameter > 0 |
| 9 | `test_RevertWhen_ValidateVm_WithInvalidSender` | Wrong sender reverts `VmAlreadyValidated` (or similar) | `validateVm()` → `msg.sender != _vmEthereumAddress[posHash]` | Wrong prank address |
| 10 | `test_RevertWhen_ValidateVm_AlreadyValidated` | Already validated VM reverts | `validateVm()` → checks pending state | Validate twice |

#### VM Retrieval (3 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 11 | `test_GetVm_Should_ReturnCorrectVm_When_ValidIdProvided` | Get VM by vmId returns all fields | `DidManager.getVm()` → `calculatePositionHash()` → reads all `_vm*[posHash]` fields | Known vmId |
| 12 | `test_GetVm_Should_ReturnCorrectVm_When_ValidPositionProvided` | Get VM by enumerated position | `getVm()` → `EnumerableSet.at(position)` → reads storage | Position index |
| 13 | `test_GetVm_Should_ReturnEmptyVm_When_InvalidPositionProvided` | Invalid position returns empty VM struct | `getVm()` → bounds check → empty return | Out-of-bounds |

#### Relationship (5 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 14 | `test_IsVmRelationship_Should_ReturnTrue_When_RelationshipExists` | Valid relationship returns true | `VMStorage._isVmRelationship()` → `_vmRelationships[posHash] & relationship != 0` | Matching bitmask |
| 15 | `test_IsVmRelationship_Should_ReturnFalse_When_RelationshipDoesNotMatch` | Non-matching returns false | `_isVmRelationship()` → bitmask AND == 0 | Non-matching flag |
| 16 | `test_IsVmRelationship_Should_RevertWithMissingParameter_When_ZeroValuesProvided` | Zero values revert `MissingRequiredParameter` | `_isVmRelationship()` → validation | methods/id/vmId = bytes32(0) |
| 17 | `test_IsVmRelationship_Should_RevertWithOutOfRange_When_InvalidRelationshipProvided` | Invalid relationship (> 0x1F) reverts `VmRelationshipOutOfRange` | `_isVmRelationship()` → bounds check | relationship=0x20 |
| 18 | `test_IsVmRelationship_Should_CheckRelationshipOnly_When_CalledInternally` | Internal call checks relationship without sender validation | `_isVmRelationship()` internal path | Direct internal call |

#### VM List (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 19 | `test_GetVmListLength_Should_ReturnCorrectCount_When_VmsExist` | Returns correct count | `DidManager.getVmListLength()` → `EnumerableSet.length()` | Multiple VMs |
| 20 | `test_GetVmListLength_Should_ReturnZero_When_DidDoesNotExist` | Zero for non-existent DID | `getVmListLength()` | Non-existent hash |

#### VM Expiration (2 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 21 | `test_ExpireVm_Should_SetExpirationToCurrentTime_When_ValidVmProvided` | VM expiration set to `block.timestamp` | `VMStorage._expireVmInternal()` → `_vmExpiration[posHash] = block.timestamp` | Authenticated owner |
| 22 | `test_RevertWhen_ExpireVm_AlreadyExpired` | Already expired reverts `VmAlreadyExpired` | `_expireVmInternal()` → `_vmExpiration[posHash] <= block.timestamp` | Expired VM |

#### Cleanup (3 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 23 | `test_RemoveAllVms_Should_ExecuteWhileLoopBody_When_MultipleVmsExist` | While loop body executes for each VM removal | `VMStorage._removeAllVms()` → `EnumerableSet.length()` > 0 → `at(0)` → `remove()` → repeat | Multiple VMs pre-created |
| 24 | `test_RemoveAllVms_Should_ExecuteWhileLoop_When_VmsExist` | While loop executes with single VM | `_removeAllVms()` | Single VM |
| 25 | `test_RemoveAllVms_Should_CoverAllCleanupLogic_When_MultipleVmsWithPositionHashes` | Full cleanup including position hash storage deletion | `_removeAllVms()` → deletes `_vmType`, `_vmPublicKey`, `_vmBlockchainAccountId`, `_vmEthereumAddress`, `_vmRelationships`, `_vmExpiration` per posHash | Multiple VMs with different posHashes |

#### Edge Cases (5 tests)

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 26 | `test_ValidateVm_Should_RevertWithVmNotFound_When_InvalidPositionHashProvided` | Invalid position hash reverts `VmNotFound` | `validateVm()` → posHash not in set | Random posHash |
| 27 | `test_ValidateVm_Should_RevertWithInvalidSignature_When_EthereumAddressMismatch` | Address mismatch during validation reverts | `validateVm()` → `msg.sender != _vmEthereumAddress[posHash]` | Wrong address prank |
| 28 | `test_CreateVm_Should_HandleAllEmptyInputs_When_RequiredFieldsMissing` | All empty inputs properly handled/reverted | `_createVmInternal()` → validation cascade | All fields empty |
| 29 | `test_GetVm_Should_ReturnEmpty_When_InvalidPositionRequested` | Invalid position returns empty VM | `getVm()` → bounds check | Large position value |
| 30 | `test_IsVmRelationship_Should_CheckRelationshipOnly_When_SenderIsZero` | Zero sender (address(0)) in relationship check | `_isVmRelationship()` → sender validation path | sender=address(0) |

---

### 7. `W3CResolver.unit.t.sol` — 22 tests

**File**: `test/unit/W3CResolver.unit.t.sol`
**Contract**: `W3CResolverUnitTest`
**Primary targets**: `W3CResolver.resolve()`, `W3CResolverBase.resolveVm()`, `W3CResolverBase.resolveService()`, `W3CResolverUtils`

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_Resolve_Should_ReturnValidDidDocument_When_BasicDidExists` | Returns valid W3C DID document with all required fields | `W3CResolver.resolve()` → `_getAllVerificationMethods()` → `IDidReadOps.getVm()` → `IDidReadOps.getService()` → `W3CResolverUtils.formatDidString()` | Basic DID with default VM |
| 2 | `test_Resolve_Should_IncludeVerificationMethods_When_VmsExist` | VMs included in document's verificationMethod array | `resolve()` → `_getAllVerificationMethods()` → iterates `getVmListLength()` VMs | Multiple VMs created |
| 3 | `test_Resolve_Should_IncludeServices_When_ServicesExist` | Services included in document | `resolve()` → `W3CResolverUtils.toW3cService()` → `parsePackedStrings()` | Services created |
| 4 | `test_Resolve_Should_ExcludeExpiredMethods_When_IncludeExpiredFalse` | Expired VMs filtered from output | `resolve()` with includeExpired=false → checks `_vmExpiration[posHash] <= block.timestamp` | Expired VM via `vm.warp()` |
| 5 | `test_Resolve_Should_IncludeExpiredMethods_When_IncludeExpiredTrue` | Expired VMs included when flag set | `resolve()` with includeExpired=true | Expired VM present |
| 6 | `test_ResolveVm_Should_ReturnVerificationMethod_When_ValidVmIdProvided` | Single VM resolution by ID | `W3CResolverBase.resolveVm()` → `IDidReadOps.getVm()` → W3C formatting | Known vmId |
| 7 | `test_ResolveVm_Should_ReturnEmptyVm_When_NonExistentVmIdProvided` | Non-existent VM returns empty W3C VM struct | `resolveVm()` → empty storage | Random vmId |
| 8 | `test_ResolveService_Should_ReturnService_When_ValidServiceIdProvided` | Single service resolution by ID | `W3CResolverBase.resolveService()` → `IDidReadOps.getService()` → `W3CResolverUtils.toW3cService()` | Known serviceId |
| 9 | `test_ResolveService_Should_ReturnEmptyService_When_NonExistentServiceIdProvided` | Non-existent service returns empty | `resolveService()` → empty storage | Random serviceId |
| 10 | `test_Resolve_Should_PopulateAssertionMethodArray_When_VmHas0x02Flag` | assertionMethod array in document populated | `resolve()` → bitmask 0x02 → `W3CDidDocument.assertionMethod` | VM with assertion flag |
| 11 | `test_Resolve_Should_PopulateKeyAgreementArray_When_VmHas0x04Flag` | keyAgreement array populated | `resolve()` → bitmask 0x04 → `W3CDidDocument.keyAgreement` | VM with keyAgreement flag |
| 12 | `test_Resolve_Should_PopulateMultipleRelationshipArrays_When_VmHasCombinedFlags` | Multiple relationship arrays populated from combined bitmask | `resolve()` → bitmask has multiple flags → multiple arrays populated | VM with combined flags (e.g., 0x03) |
| 13 | `test_Resolve_Should_IncludeCapabilityInvocationMethods_When_VmHasCapabilityInvocation` | capabilityInvocation array populated | `resolve()` → bitmask 0x08 → `W3CDidDocument.capabilityInvocation` | VM with capInvocation flag |
| 14 | `test_Resolve_Should_HandleCapabilityDelegationMethods_When_VmHasCapabilityDelegation` | capabilityDelegation array populated | `resolve()` → bitmask 0x10 → `W3CDidDocument.capabilityDelegation` | VM with capDelegation flag |
| 15 | `test_Resolve_Should_ReturnCompleteDocument_When_ComplexDidExists` | Complete document with VMs + services + controllers + all relationship arrays | `resolve()` → full document assembly | DID with multiple VMs, services, controllers |
| 16 | `test_Resolve_Should_HandleDidWithDefaultVm_When_NoAdditionalVmsOrServicesExist` | Minimal DID with only default VM resolves correctly | `resolve()` → only default VM in output | DID with no extra VMs/services |
| 17 | `test_Resolve_Should_IncludeControllerList_When_ControllersAreSet` | Controllers included in document's controller array | `resolve()` → `W3CResolverUtils.toW3cController()` → formats controller DID strings | Controllers set via `updateController()` |
| 18 | `test_Resolve_Should_ConvertExpirationToMilliseconds_When_Resolving` | Expiration converted from seconds to milliseconds (×1000) for W3C compliance | `resolve()` → `expiration * 1000` in output | Known expiration timestamp |
| 19 | `test_BytesToHexString_Should_ConvertBytesToHexString_When_Called` | Hex string conversion utility works correctly | `W3CResolverUtils.bytesToHexString()` | Known input bytes |
| 20 | `test_RevertWhen_ResolveVm_WithEmptyDidInput` | Empty DID input (zero methods/id) reverts | `resolveVm()` → `W3CResolverUtils.checkDidInput()` → reverts | Zero params |
| 21 | `test_RevertWhen_ResolveService_WithEmptyDidInput` | Empty DID input reverts | `resolveService()` → `checkDidInput()` → reverts | Zero params |
| 22 | `test_ValidateDidInput_Should_SetDefaultMethods_When_MethodsIsEmpty` | Empty methods defaulted to `DEFAULT_DID_METHODS` during resolution | `checkDidInput()` → methods=bytes32(0) → DEFAULT_DID_METHODS | methods=bytes32(0) |

---

### 8. `W3CResolverNative.unit.t.sol` — 27 tests

**File**: `test/unit/W3CResolverNative.unit.t.sol`
**Contract**: `W3CResolverNativeUnitTest`
**Primary targets**: `W3CResolverNative.resolve()`, `W3CResolverNative._getAllVerificationMethods()`, `W3CResolverBase.resolveVm()`, `W3CResolverBase.resolveService()`

Shares 20 tests with W3CResolver (adapted for native), **plus** 7 native-specific tests:

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_Resolve_Should_ReturnValidDidDocument_When_BasicDidExists` | Valid document from native manager | `W3CResolverNative.resolve()` → `_getAllVerificationMethods()` | Basic native DID |
| 2 | `test_Resolve_Should_HandleDidWithDefaultVm_When_NoAdditionalVmsOrServicesExist` | Default VM handling in native | `resolve()` → default VM resolution | Minimal DID |
| 3 | `test_Resolve_Should_DeriveBlockchainAccountId_When_EthereumAddressPresent` | CAIP-10 blockchain account ID derived at resolution time (zero extra storage) | `_getAllVerificationMethods()` → `string.concat("eip155:", chainId, ":", addressHex)` | Native VM with address |
| 4 | `test_Resolve_Should_UseBlockChainId_When_ConstructingBlockchainAccountId` | Correct chain ID used in CAIP-10 format | `_getAllVerificationMethods()` → `block.chainid` | Check chain ID in output |
| 5 | `test_Resolve_Should_IncludeServices_When_ServicesExist` | Services in native document | `resolve()` → `toW3cService()` | Services created |
| 6 | `test_Resolve_Should_IncludeVerificationMethods_When_VmsExist` | VMs in native document | `resolve()` → `_getAllVerificationMethods()` | Multiple VMs |
| 7 | `test_Resolve_Should_IncludeControllers_When_ControllersExist` | Controllers in document | `resolve()` → `toW3cController()` | Controllers set |
| 8 | `test_Resolve_Should_ExcludeExpiredMethods_When_IncludeExpiredFalse` | Expired filtered | `resolve()` with includeExpired=false | Expired VM |
| 9 | `test_Resolve_Should_IncludeExpiredMethods_When_IncludeExpiredTrue` | Expired included | `resolve()` with includeExpired=true | Expired VM |
| 10 | `test_ResolveVm_Should_ReturnVerificationMethod_When_ValidVmIdProvided` | VM resolution | `resolveVm()` | Known vmId |
| 11 | `test_ResolveVm_Should_ReturnEmptyVm_When_NonExistentVmIdProvided` | Non-existent empty | `resolveVm()` | Random vmId |
| 12 | `test_ResolveService_Should_ReturnService_When_ValidServiceIdProvided` | Service resolution | `resolveService()` | Known serviceId |
| 13 | `test_Resolve_Should_ParseMultipleServiceTypes_When_DelimiterPackedValues` | Multiple packed types parsed at resolution | `W3CResolverUtils.parsePackedStrings()` → splits on `;` delimiter | Packed type_ field |
| 14 | `test_ResolveService_Should_ParseMultipleTypes_When_DelimiterPackedValues` | Service type parsing via resolveService | `resolveService()` → `parsePackedStrings()` | Packed values |
| 15 | `test_Resolve_Should_ReturnEmptyPublicKeyMultibase_When_NonKeyAgreementVm` | Non-keyAgreement VMs have empty publicKeyMultibase in resolved document | `_getAllVerificationMethods()` → `getVmPublicKeyMultibase()` returns empty | VM without 0x04 flag |
| 16 | `test_Resolve_Should_ReturnPublicKeyMultibase_When_KeyAgreementVm` | keyAgreement VMs include publicKeyMultibase in resolved document | `_getAllVerificationMethods()` → `getVmPublicKeyMultibase()` returns stored key | VM with 0x04 + valid key |
| 17 | `test_ResolveVm_Should_ReturnPublicKeyMultibase_When_KeyAgreementVm` | VM-level resolution includes publicKeyMultibase | `resolveVm()` → reads key from overflow storage | keyAgreement VM |
| 18 | `test_Resolve_Should_PopulateAllRelationships_When_VmHasAllRelationships` | All 5 relationship arrays populated | `resolve()` → bitmask=0x1F → all arrays | VM with all flags |
| 19 | `test_Resolve_Should_PopulateKeyAgreementArray_When_VmHas0x04Flag` | keyAgreement array populated | `resolve()` → bitmask 0x04 | keyAgreement VM |
| 20 | `test_BytesToHexString_Should_ConvertCorrectly_When_ValidInputProvided` | Hex conversion correct | `W3CResolverUtils.bytesToHexString()` | Known bytes |
| 21 | `test_BytesToHexString_Should_ReturnEmpty_When_EmptyInputProvided` | Empty input returns empty string | `bytesToHexString()` | Empty bytes |
| 22 | `test_RevertWhen_ResolveVm_WithEmptyDidInput` | Empty input reverts | `resolveVm()` → `checkDidInput()` | Zero params |
| 23 | `test_RevertWhen_ResolveService_WithEmptyDidInput` | Empty input reverts | `resolveService()` → `checkDidInput()` | Zero params |
| 24 | `test_ValidateDidInput_Should_SetDefaultMethods_When_MethodsIsEmpty` | Default methods set | `checkDidInput()` | methods=bytes32(0) |
| 25 | `test_Resolve_Should_TrimTrailingEmpty_When_ServiceTypeHasTrailingDelimiter` | Trailing delimiter trimmed from service types | `W3CResolverUtils.trimBytes()` → removes trailing empty entries | type_ with trailing `;` |
| 26 | `test_Resolve_Should_ReturnEmptyArray_When_ServiceTypeIsOnlyDelimiter` | Delimiter-only type returns empty array | `parsePackedStrings()` → all entries empty after split | type_=";" |
| 27 | `test_Resolve_Should_ConvertExpirationToMilliseconds_When_Resolving` | Millisecond conversion | `resolve()` → ×1000 | Known timestamp |

---

## Fuzz Tests

### 9. `DidManager.fuzz.t.sol` — 10 tests

**File**: `test/fuzz/DidManager.fuzz.t.sol`
**Contract**: `DidManagerFuzzTest`
**CI Profile**: `ci` (fuzz_runs=256), `ci_thorough` (fuzz_runs=1000)

| # | Test Name | What It Does | Production Functions Touched | Fuzz Parameters |
|---|-----------|-------------|------------------------------|----------------|
| 1 | `testFuzz_CreateDid_Should_AlwaysSucceed_When_RandomIsNonZero` | Any non-zero random value creates DID | `createDid()` → `_createDidInternal()` | `random: bytes32` (bounded ≠ 0) |
| 2 | `testFuzz_CreateDid_Should_PreserveMethods_When_CustomMethodsProvided` | Custom methods survive storage roundtrip | `createDid()` → `getExpiration()` verifies existence | `methods: bytes32`, `random: bytes32` |
| 3 | `testFuzz_CreateDid_Should_FailOnDuplicate_When_SameInputsUsed` | Same inputs always revert on 2nd call | `createDid()` x2 → `DidAlreadyExists` | `random: bytes32` |
| 4 | `testFuzz_CreateVm_Should_Succeed_When_ValidRelationshipsProvided` | Any valid relationship bitmask (1-31) succeeds | `createVm()` → `_createVmInternal()` | `relationships: uint8` (bounded 1-31) |
| 5 | `testFuzz_CreateVm_Should_HandleDifferentAddresses_When_ValidAddressProvided` | Any non-zero address works as VM Ethereum address | `createVm()` with fuzzed address | `addr: address` (bounded ≠ 0) |
| 6 | `testFuzz_Authenticate_Should_BeConsistent_When_ValidVmUsed` | Authentication always consistent for valid VM owner | `_isAuthenticated()` → `_isVmOwner()` | `random: bytes32` (setup variation) |
| 7 | `testFuzz_VmRelationships_Should_MatchCreated_When_ValidRelationshipsBitmask` | All 5 relationship flags individually verified after creation | `_isVmRelationship()` with each of 0x01-0x10 | `relationships: uint8` (bounded 1-31) |
| 8 | `testFuzz_Expiration_Should_BehaveProperly_When_TimeAdvances` | Time-based expiration correct across fuzzed timestamps | `_isExpired()` via `vm.warp(fuzzedTime)` | `warpTime: uint256` |
| 9 | `testFuzz_CreateVm_Should_RejectInvalidRelationships_When_OutOfRange` | Any value > 0x1F always reverts `VmRelationshipOutOfRange` | `createVm()` → validation | `relationships: uint8` (bounded 32-255) |
| 10 | `testFuzz_DeactivateReactivate_Should_PreserveData_When_Cycled` | Deactivate→reactivate cycle preserves all VM/service data | `deactivateDid()` → `reactivateDid()` → `getVm()` comparison | `random: bytes32` |

---

### 10. `DidManagerNative.fuzz.t.sol` — 11 tests

**File**: `test/fuzz/DidManagerNative.fuzz.t.sol`
**Contract**: `DidManagerNativeFuzzTest`

Same 10 tests as above adapted for native **plus**:

| # | Test Name | What It Does | Production Functions Touched | Fuzz Parameters |
|---|-----------|-------------|------------------------------|----------------|
| 1-10 | *(Same as DidManager.fuzz.t.sol)* | Native variants of all 10 fuzz tests | `DidManagerNative.*`, `VMStorageNative.*` | Same as above |
| 11 | `testFuzz_IsAuthorized_Should_CheckRelationshipsMask_When_VaryingRelationships` | Authorization respects fuzzed relationship mask combinations | `isAuthorized()` with fuzzed relationships | `relationships: uint8`, `queryRelationship: uint8` |

---

## Integration Tests

### 11. `DidLifecycle.integration.t.sol` — 6 tests

**File**: `test/integration/DidLifecycle.integration.t.sol`
**Contract**: `DidLifecycleIntegrationTest`
**Purpose**: End-to-end workflows spanning multiple contracts

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_CompleteDidLifecycle_Should_WorkEndToEnd_When_AllStepsExecuted` | Full lifecycle: create DID → add VMs → set controllers → add services → resolve → deactivate → reactivate → verify | ALL major functions: `DidManager.createDid()`, `createVm()`, `DidAggregate.updateController()`, `ServiceStorage.updateService()`, `W3CResolver.resolve()`, `deactivateDid()`, `reactivateDid()` | Multiple users, full state transitions |
| 2 | `test_MultiUserInteraction_Should_WorkCorrectly_When_MultipleUsersCollaborate` | User A creates DID, delegates controller to User B, B creates VM on A's DID | `createDid()`, `updateController()`, `createVm()` cross-address | `vm.prank(userA)`, `vm.prank(userB)` |
| 3 | `test_ErrorRecovery_Should_HandleFailuresGracefully_When_InvalidOperationsAttempted` | Invalid operations (expired DID, wrong sender, etc.) don't corrupt state | Multiple revert scenarios → state verification after each | Try-catch pattern, state assertions |
| 4 | `test_FullLifecycle_CreateModifyResolveModifyResolve_ShouldReflectChanges` | Modifications reflected in subsequent resolutions | `createDid()` → `createVm()` → `resolve()` → `updateService()` → `resolve()` → verify changes | Two resolution snapshots compared |
| 5 | `test_DeactivateReactivate_ShouldPreserveServicesAndControllers` | Full data preservation through deactivation/reactivation cycle | `deactivateDid()` → `reactivateDid()` → compare VMs, services, controllers | Pre/post state comparison |
| 6 | `test_ControllerUpdate_OldControllerShouldLoseAccess` | Old controller loses access after being replaced | `updateController(pos, newController)` → old controller `createVm()` reverts | Controller replacement scenario |

---

### 12. `KeyAgreementE2E.t.sol` — 3 tests

**File**: `test/integration/KeyAgreementE2E.t.sol`
**Contract**: `KeyAgreementE2ETest`
**Purpose**: End-to-end key agreement and ECDH cryptographic operations

| # | Test Name | What It Does | Production Functions & Contracts Touched | Notable Setup |
|---|-----------|-------------|------------------------------------------|---------------|
| 1 | `test_KeyAgreement_ECDH_E2E_Should_EncryptAndDecrypt_When_SharedSecretDerived` | Full ECDH flow: create DIDs with keyAgreement VMs → derive shared secret → encrypt → decrypt | `createDid()`, `createVm()` with keyAgreement(0x04), secp256k1 EC multiply, XOR encrypt/decrypt | Two parties with private keys, `vm.addr()` for public keys |
| 2 | `test_Secp256k1_ECMul_Should_MatchFoundryWallet_When_MultiplyingGenerator` | secp256k1 scalar multiplication matches Foundry's `vm.addr()` | EVM precompile ecMul (address 0x07), `vm.addr(privateKey)` | Generator point G, known private key |
| 3 | `test_Secp256k1_CompressDecompress_Should_RoundTrip_When_ValidPublicKey` | Public key compression/decompression roundtrip (33 bytes ↔ 64 bytes) | Modular arithmetic, point compression prefix (0x02/0x03) | Known secp256k1 point |

---

## Invariant Tests

### 13. `SystemInvariants.t.sol` — 7 invariants

**File**: `test/invariant/SystemInvariants.t.sol`
**Contract**: `SystemInvariantsTest`
**Handler**: `DidManagerHandler` (generates random DID/VM operations)
**CI Profile**: `ci` (invariant_runs=64, depth=32), `ci_thorough` (runs=256, depth=64)

| # | Invariant Name | Property Verified | Contracts Checked |
|---|---------------|-------------------|-------------------|
| 1 | `invariant_DidIdsShouldNeverBeZero` | All created DIDs have non-zero IDs (bytes32 ≠ 0) | Handler ghost variable `createdDids[]` |
| 2 | `invariant_DidExpirationShouldAlwaysBeInFuture` | DID expirations always > block.timestamp at creation time | `DidAggregate.getExpiration()` for each created DID |
| 3 | `invariant_VmCountShouldBeReasonable` | VM count per DID within reasonable bounds (no overflow) | `DidManager.getVmListLength()` |
| 4 | `invariant_HandlerStateShouldBeConsistent` | Handler's ghost variables match actual contract state | Handler counters vs contract queries |
| 5 | `invariant_NoDuplicateDidsShouldExist` | All DID idHashes are unique (no hash collisions in test) | Handler `createdDids[]` uniqueness check |
| 6 | `invariant_ExpiredDidsShouldNeverAuthenticate` | Expired DIDs fail `_isAuthenticated()` check | `_isAuthenticated()` after `vm.warp()` past expiration |
| 7 | `invariant_VmCountShouldMatchEnumerableSetLength` | `getVmListLength()` matches internal EnumerableSet state | `getVmListLength()` vs handler tracking |

---

### 14. `NativeSystemInvariants.t.sol` — 8 invariants

**File**: `test/invariant/NativeSystemInvariants.t.sol`
**Contract**: `NativeSystemInvariantsTest`
**Handler**: `DidManagerNativeHandler`

Same 7 invariants as above for native variant **plus**:

| # | Invariant Name | Property Verified | Contracts Checked |
|---|---------------|-------------------|-------------------|
| 8 | `invariant_PublicKeyMultibaseShouldOnlyExistForKeyAgreement` | `publicKeyMultibase` is non-empty ONLY when VM has keyAgreement (0x04) relationship | `getVmPublicKeyMultibase()` cross-referenced with `_isVmRelationship(0x04)` |

---

## Performance Tests

### 15. `GasOptimization.performance.t.sol` — 8 tests

**File**: `test/performance/GasOptimization.performance.t.sol`
**Contract**: `GasOptimizationPerformanceTest`
**Purpose**: Gas cost benchmarking for academic research metrics
**CI**: Excluded from default profile, runs in `ci_thorough` only

| # | Test Name | What It Does | Operations Measured | Metrics |
|---|-----------|-------------|---------------------|---------|
| 1 | `test_GasBenchmark_CreateDid_BaselineOperation` | DID creation gas baseline | `createDid()` single call | `gasleft()` before/after delta |
| 2 | `test_GasBenchmark_CreateVm_StandardOperation` | VM creation gas | `createVm()` single call | `gasleft()` delta |
| 3 | `test_GasBenchmark_UpdateService_StandardOperation` | Service update gas | `updateService()` single call | `gasleft()` delta |
| 4 | `test_GasBenchmark_CreateMultipleVms_ScalingAnalysis` | VM creation scaling (1→N VMs) | `createVm()` x N, measure each | Per-VM gas, scaling factor |
| 5 | `test_GasBenchmark_CreateMultipleServices_ScalingAnalysis` | Service creation scaling (1→N services) | `updateService()` x N | Per-service gas, scaling factor |
| 6 | `test_GasBenchmark_Authentication_PerformanceValidation` | Authentication gas cost | `_isAuthenticated()` via external call | Authentication overhead |
| 7 | `test_GasBenchmark_CleanupOperations_PerformanceAnalysis` | Cleanup operation gas (DID recreation) | `_removeAllVms()` + `_removeAllServices()` via `createDid()` | Cleanup cost vs data size |
| 8 | `test_GenerateAcademicGasMetrics_ComprehensiveDataset` | Comprehensive gas metrics dataset for research publication | All operations combined, formatted output | Full dataset for papers |

---

## Stress Tests

### 16. `StressTest.t.sol` — 6 tests

**File**: `test/stress/StressTest.t.sol`
**Contract**: `StressTest`
**Purpose**: System limits and boundary condition validation
**CI**: Excluded from default profile, runs in `ci_thorough` only

| # | Test Name | What It Does | Limits Tested | Notable Assertions |
|---|-----------|-------------|---------------|-------------------|
| 1 | `test_StressTest_MaximumVms_SystemLimits` | Maximum VM capacity per DID before gas limit | VM count upper bound | Gas remains reasonable, no OOG |
| 2 | `test_StressTest_MaximumServices_SystemLimits` | Maximum service capacity per DID | Service count upper bound | EnumerableSet handles scale |
| 3 | `test_StressTest_MaximumControllers_SystemLimits` | Maximum controllers (`CONTROLLERS_MAX_LENGTH` = 5) | All 5 controller slots used | Boundary behavior at max |
| 4 | `test_StressTest_LargeDataStructures_PerformanceValidation` | Large data structures (many VMs + services + controllers) | Combined stress | Resolution still works |
| 5 | `test_StressTest_RapidOperations_ConcurrentSimulation` | Rapid consecutive operations (create/modify cycles) | Throughput | No state corruption |
| 6 | `test_StressTest_SystemResilience_ErrorRecovery` | Error recovery under stress conditions | Revert recovery | State consistency after failures |

---

## Helper & Fixture Files

These files are not test files but support the test infrastructure:

| File | Purpose | Key Contents |
|------|---------|-------------|
| `test/helpers/SharedTest.sol` | Base test contract inherited by all tests | `_createDid()`, `_createVm()`, default constants (`DEFAULT_RANDOM_*`, `DEFAULT_VM_*`), manager deployment, prank helpers |
| `test/helpers/Fixtures.sol` | Test fixture data | `emptyVmPublicKeyMultibase()`, default values, fixture structs |
| `test/helpers/DidManagerHandler.sol` | Invariant test handler (Full W3C) | Random DID/VM creation, ghost variables for invariant tracking, `vm.prank()` management |
| `test/helpers/DidManagerNativeHandler.sol` | Invariant test handler (Native) | Native variant handler with keyAgreement enforcement tracking |

---

## Coverage by Production Contract

| Production Contract | Test Files Covering It | Approximate Test Count |
|---------------------|----------------------|----------------------:|
| **DidAggregate** (shared lifecycle) | Authorize, AuthorizeOffChain, DidManager, DidManagerNative, DidLifecycle | ~180 |
| **VMStorage** (Full W3C VMs) | VMStorage.unit, DidManager.unit, W3CResolver.unit, fuzz, invariant | ~90 |
| **VMStorageNative** (Native VMs) | DidManagerNative.unit, W3CResolverNative.unit, native fuzz/invariant | ~83 |
| **ServiceStorage** (services) | ServiceStorage.unit, DidManager.unit, DidLifecycle | ~25 |
| **W3CResolver** (Full W3C resolution) | W3CResolver.unit | 22 |
| **W3CResolverNative** (Native resolution) | W3CResolverNative.unit | 27 |
| **W3CResolverBase** (shared resolution) | Both resolver test files | ~49 |
| **W3CResolverUtils** (shared library) | Both resolver test files | ~10 |
| **HashUtils** (hash library) | Indirectly via ALL storage tests | all |
| **DidManager** (Full W3C wrapper) | DidManager.unit, fuzz, invariant, integration | ~78 |
| **DidManagerNative** (Native wrapper) | DidManagerNative.unit, native fuzz/invariant | ~84 |
| **VMHooks** (abstract hooks) | Indirectly via all manager/storage tests | all |

---

**Last Updated**: 2026-03-10
**Total Test Count**: 343
**Test Framework**: Foundry (forge test)
**Coverage Target**: >90% (enforced in CI/CD)
