// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { DidTestHelpers } from "@test/helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "@test/helpers/DidTestHelpersNative.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { DidCreateVmCommandNative as NativeCreateVmCommand } from "@types/VmTypesNative.sol";
import { DEFAULT_VM_ID, IVMStorage } from "@interfaces/IVMStorage.sol";
import { DEFAULT_VM_ID_NATIVE, IVMStorageNative } from "@interfaces/IVMStorageNative.sol";
import "@types/DidTypes.sol";

// =========================================================================
// Full W3C Variant Tests
// =========================================================================

contract AuthorizeUnitTest is TestBase {
  address internal user1 = Fixtures.TEST_USER_1;
  address internal user2 = Fixtures.TEST_USER_2;
  address internal user3 = Fixtures.TEST_USER_3;

  function setUp() public {
    _deployDidManager();
    _setupUser(user1, "User1");
    _setupUser(user2, "User2");
    _setupUser(user3, "User3");
  }

  // =========================================================================
  // HAPPY PATHS
  // =========================================================================

  /// @notice Self-controlled DID with assertionMethod → true
  function test_IsAuthorized_Should_ReturnTrue_When_SelfControlledWithAssertionMethod() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create VM with auth + assertion (0x03) for user1
    _stopPrank();
    _startPrank(user1);
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-assertion"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    bool authorized = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-assertion"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user1
    );
    assertTrue(authorized, "Self-controlled DID with assertionMethod should be authorized");
    _stopPrank();
  }

  /// @notice Controller-managed DID, controller has assertionMethod → true
  function test_IsAuthorized_Should_ReturnTrue_When_ControllerHasAssertionMethod() public {
    // Create target DID as user1
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Create controller DID as user2 with auth + assertion VM
    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));

    // Create assertion VM on controller DID
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-assertion"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    // Set user2's DID as controller of user1's DID
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0), // No specific VM required
      0
    );
    _stopPrank();

    bool authorized = didManager.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      bytes32("vm-assertion"),
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user2
    );
    assertTrue(authorized, "Controller with assertionMethod should be authorized");
  }

  /// @notice Controller without VM restriction (vmId=0), any VM works → true
  function test_IsAuthorized_Should_ReturnTrue_When_ControllerWithoutVmRestriction() public {
    // Create target DID as user1
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Create controller DID as user2
    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set controller with vmId=0 (any VM accepted)
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0), // No VM restriction
      0
    );
    _stopPrank();

    // Controller's default VM has auth (0x01) — check with auth relationship
    bool authorized = didManager.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertTrue(authorized, "Controller with no VM restriction should be authorized");
  }

  /// @notice keyAgreement (0x04) relationship → true
  function test_IsAuthorized_Should_ReturnTrue_When_KeyAgreementRelationship() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create VM with auth + keyAgreement (0x05)
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-ka"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_KEY_AGREEMENT,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    bool authorized = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-ka"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,
      user1
    );
    assertTrue(authorized, "Self-controlled DID with keyAgreement should be authorized");
  }

  // =========================================================================
  // AUTHORIZATION FAILURES (return false, NOT revert)
  // =========================================================================

  /// @notice Self-controlled, VM only has auth (0x01), ask for assertion (0x02) → false
  function test_IsAuthorized_Should_ReturnFalse_When_VmLacksRequestedRelationship() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Default VM only has auth (0x01), asking for assertion (0x02)
    bool authorized = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user1
    );
    assertFalse(authorized, "VM without assertion should not be authorized for assertion");
  }

  /// @notice Controller has auth but NOT assertionMethod → false
  function test_IsAuthorized_Should_ReturnFalse_When_ControllerVmLacksRelationship() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set controller
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    // Controller's default VM only has auth (0x01), asking for assertion (0x02)
    bool authorized = didManager.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user2
    );
    assertFalse(authorized, "Controller without assertion relationship should not be authorized");
  }

  /// @notice Non-controller caller → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderIsNotController() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory nonControllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set a different controller (user3) so controllers list is non-empty
    _startPrank(user3);
    DidTestHelpers.CreateDidResult memory actualControllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0));
    _stopPrank();

    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      actualControllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    // user2 is NOT a controller
    bool authorized = didManager.isAuthorized(
      targetDid.didInfo.methods,
      nonControllerDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertFalse(authorized, "Non-controller should not be authorized");
  }

  /// @notice Expired sender DID → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderDidExpired() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Warp past DID expiration (4 years + buffer)
    vm.warp(block.timestamp + Fixtures.WARP_TO_EXPIRE_DID);

    bool authorized = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );
    assertFalse(authorized, "Expired sender DID should not be authorized");
  }

  /// @notice Expired target DID → false
  function test_IsAuthorized_Should_ReturnFalse_When_TargetDidExpired() public {
    // Create target DID and sender/controller DID
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory senderDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set sender as controller of target
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      senderDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    // Controller (user2) deactivates target DID
    _startPrank(user2);
    didManager.deactivateDid(targetDid.didInfo.methods, senderDid.didInfo.id, DEFAULT_VM_ID, targetDid.didInfo.id);
    _stopPrank();

    bool authorized = didManager.isAuthorized(
      targetDid.didInfo.methods,
      senderDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertFalse(authorized, "Deactivated target DID should not be authorized");
  }

  /// @notice Deactivated sender DID (expiration=0) → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderDidDeactivated() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Deactivate
    didManager.deactivateDid(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, didResult.didInfo.id);
    _stopPrank();

    bool authorized = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );
    assertFalse(authorized, "Deactivated sender DID should not be authorized");
  }

  /// @notice Expired VM on sender → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderVmExpired() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create a VM with a specific expiration
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-short-lived"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(block.timestamp + 100) // Expires in 100 seconds
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManager.validateVm(vmResult.vmCreatedPositionHash, block.timestamp + 100);
    vm.stopPrank();

    // Warp past VM expiration but before DID expiration
    vm.warp(block.timestamp + 200);

    bool authorized = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-short-lived"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );
    assertFalse(authorized, "Expired VM should not be authorized");
  }

  /// @notice Controller with VM restriction, wrong VM used → false
  function test_IsAuthorized_Should_ReturnFalse_When_ControllerUsesWrongVm() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));

    // Create a second VM for the controller
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-restricted"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    // Set controller with specific VM restriction (vm-restricted)
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32("vm-restricted"), // Only this VM is allowed
      0
    );
    _stopPrank();

    // Try to authorize with DEFAULT_VM_ID instead of vm-restricted → should fail controller check
    bool authorized = didManager.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID, // Wrong VM! Controller requires vm-restricted
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertFalse(authorized, "Controller with wrong VM should not be authorized");
  }

  // =========================================================================
  // INVALID INPUTS (revert)
  // =========================================================================

  /// @notice Missing parameters → revert MissingRequiredParameter
  function test_RevertWhen_IsAuthorized_WithMissingParameters() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Zero methods
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorized(bytes32(0), didResult.didInfo.id, DEFAULT_VM_ID, didResult.didInfo.id, bytes1(0x01), user1);

    // Zero senderId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorized(
      didResult.didInfo.methods, bytes32(0), DEFAULT_VM_ID, didResult.didInfo.id, bytes1(0x01), user1
    );

    // Zero senderVmId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, bytes32(0), didResult.didInfo.id, bytes1(0x01), user1
    );

    // Zero targetId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, bytes32(0), bytes1(0x01), user1
    );

    // Zero relationship
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, didResult.didInfo.id, bytes1(0), user1
    );

    // Zero address
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, didResult.didInfo.id, bytes1(0x01), address(0)
    );
  }

  /// @notice Invalid relationship (0x20) → revert VmRelationshipOutOfRange
  function test_RevertWhen_IsAuthorized_WithInvalidRelationship() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    vm.expectRevert(VmRelationshipOutOfRange.selector);
    didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_INVALID, // 0x20
      user1
    );
  }
}

// =========================================================================
// Native Variant Tests
// =========================================================================

contract AuthorizeNativeUnitTest is TestBaseNative {
  address internal user1 = Fixtures.TEST_USER_1;
  address internal user2 = Fixtures.TEST_USER_2;
  address internal user3 = Fixtures.TEST_USER_3;

  function setUp() public {
    _deployDidManagerNative();
    _setupUser(user1, "User1");
    _setupUser(user2, "User2");
    _setupUser(user3, "User3");
  }

  // =========================================================================
  // HAPPY PATHS
  // =========================================================================

  /// @notice Self-controlled DID with assertionMethod → true
  function test_IsAuthorized_Should_ReturnTrue_When_SelfControlledWithAssertionMethod() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create VM with auth + assertion (0x03)
    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-assertion"),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-assertion"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user1
    );
    assertTrue(authorized, "Self-controlled DID with assertionMethod should be authorized");
  }

  /// @notice Controller-managed DID, controller has assertionMethod → true
  function test_IsAuthorized_Should_ReturnTrue_When_ControllerHasAssertionMethod() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // Create assertion VM on controller DID
    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-assertion"),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    // Set controller
    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      bytes32("vm-assertion"),
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user2
    );
    assertTrue(authorized, "Controller with assertionMethod should be authorized");
  }

  /// @notice Controller without VM restriction → true
  function test_IsAuthorized_Should_ReturnTrue_When_ControllerWithoutVmRestriction() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertTrue(authorized, "Controller with no VM restriction should be authorized");
  }

  /// @notice keyAgreement (0x04) relationship → true
  function test_IsAuthorized_Should_ReturnTrue_When_KeyAgreementRelationship() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create VM with auth + keyAgreement (0x05) — requires publicKeyMultibase for native
    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-ka"),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_KEY_AGREEMENT,
      publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase()
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-ka"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,
      user1
    );
    assertTrue(authorized, "Self-controlled DID with keyAgreement should be authorized");
  }

  // =========================================================================
  // AUTHORIZATION FAILURES (return false, NOT revert)
  // =========================================================================

  /// @notice VM only has auth (0x01), ask for assertion (0x02) → false
  function test_IsAuthorized_Should_ReturnFalse_When_VmLacksRequestedRelationship() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user1
    );
    assertFalse(authorized, "VM without assertion should not be authorized for assertion");
  }

  /// @notice Controller has auth but NOT assertionMethod → false
  function test_IsAuthorized_Should_ReturnFalse_When_ControllerVmLacksRelationship() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      user2
    );
    assertFalse(authorized, "Controller without assertion should not be authorized");
  }

  /// @notice Non-controller caller → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderIsNotController() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory nonControllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    _startPrank(user3);
    DidTestHelpersNative.CreateDidResult memory actualControllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0)
    );
    _stopPrank();

    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      actualControllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      targetDid.didInfo.methods,
      nonControllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertFalse(authorized, "Non-controller should not be authorized");
  }

  /// @notice Expired sender DID → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderDidExpired() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    vm.warp(block.timestamp + Fixtures.WARP_TO_EXPIRE_DID);

    bool authorized = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );
    assertFalse(authorized, "Expired sender DID should not be authorized");
  }

  /// @notice Expired target DID → false
  function test_IsAuthorized_Should_ReturnFalse_When_TargetDidExpired() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory senderDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Set sender as controller of target
    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      senderDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    // Controller (user2) deactivates target DID
    _startPrank(user2);
    didManagerNative.deactivateDid(
      targetDid.didInfo.methods, senderDid.didInfo.id, DEFAULT_VM_ID_NATIVE, targetDid.didInfo.id
    );
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      targetDid.didInfo.methods,
      senderDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertFalse(authorized, "Deactivated target DID should not be authorized");
  }

  /// @notice Deactivated sender DID → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderDidDeactivated() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );
    _stopPrank();

    bool authorized = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );
    assertFalse(authorized, "Deactivated sender DID should not be authorized");
  }

  /// @notice Expired VM on sender → false
  function test_IsAuthorized_Should_ReturnFalse_When_SenderVmExpired() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create a VM with short expiration — native VMs use uint88 for expiration
    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-short"),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, block.timestamp + 100);
    vm.stopPrank();

    // Warp past VM expiration
    vm.warp(block.timestamp + 200);

    bool authorized = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-short"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );
    assertFalse(authorized, "Expired VM should not be authorized");
  }

  /// @notice Controller with VM restriction, wrong VM used → false
  function test_IsAuthorized_Should_ReturnFalse_When_ControllerUsesWrongVm() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-restricted"),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32("vm-restricted"),
      0
    );
    _stopPrank();

    // Try with wrong VM
    bool authorized = didManagerNative.isAuthorized(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE, // Wrong VM
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user2
    );
    assertFalse(authorized, "Controller with wrong VM should not be authorized");
  }

  // =========================================================================
  // INVALID INPUTS (revert)
  // =========================================================================

  /// @notice Missing parameters → revert MissingRequiredParameter
  function test_RevertWhen_IsAuthorized_WithMissingParameters() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    // Zero methods
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorized(
      bytes32(0), didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, bytes1(0x01), user1
    );

    // Zero senderId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorized(
      didResult.didInfo.methods, bytes32(0), DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, bytes1(0x01), user1
    );

    // Zero senderVmId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, bytes32(0), didResult.didInfo.id, bytes1(0x01), user1
    );

    // Zero targetId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes32(0), bytes1(0x01), user1
    );

    // Zero relationship
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorized(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, bytes1(0), user1
    );

    // Zero address
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      bytes1(0x01),
      address(0)
    );
  }

  /// @notice Invalid relationship (0x20) → revert VmRelationshipOutOfRange
  function test_RevertWhen_IsAuthorized_WithInvalidRelationship() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    vm.expectRevert(VmRelationshipOutOfRange.selector);
    didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_INVALID,
      user1
    );
  }
}
