// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { IDidManagerNative, CreateVmCommand } from "@src/interfaces/IDidManagerNative.sol";
import {
  Controller,
  DEFAULT_DID_METHODS,
  CONTROLLERS_MAX_LENGTH,
  EXPIRATION,
  DidAlreadyExists,
  DidExpired,
  NotAuthenticatedAsSenderId,
  NotAControllerforTargetId,
  DidNotDeactivated
} from "@src/DidManagerBase.sol";
import {
  DEFAULT_VM_ID_NATIVE,
  DEFAULT_VM_EXPIRATION_NATIVE,
  IVMStorageNative,
  VerificationMethod
} from "@src/interfaces/IVMStorageNative.sol";
import { Vm } from "forge-std/Vm.sol";

/**
 * @title DidManagerNativeUnitTest
 * @notice Unit tests for DidManagerNative contract core functionality
 * @dev Tests the native DID manager with 1-slot VM storage
 */
contract DidManagerNativeUnitTest is TestBaseNative {
  using DidTestHelpersNative for *;

  // Test users
  address private admin = Fixtures.TEST_USER_ADMIN;
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;
  address private user3 = Fixtures.TEST_USER_3;

  function setUp() public {
    _deployDidManagerNative();

    address[] memory users = new address[](4);
    string[] memory labels = new string[](4);
    users[0] = admin;
    labels[0] = "admin";
    users[1] = user1;
    labels[1] = "user1";
    users[2] = user2;
    labels[2] = "user2";
    users[3] = user3;
    labels[3] = "user3";
    _setupUsers(users, labels);
  }

  // =========================================================================
  // CREATE DID TESTS
  // =========================================================================

  function test_CreateDid_Should_CreateWithDefaultMethods_When_EmptyMethodsProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory result = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    assertEq(result.didInfo.methods, DEFAULT_DID_METHODS);
    assertNotEq(result.didInfo.id, bytes32(0));
    assertNotEq(result.didInfo.idHash, bytes32(0));

    // Verify DID expiration is set correctly (4 years)
    uint256 didExpiration = didManagerNative.getExpiration(result.didInfo.methods, result.didInfo.id, bytes32(0));
    assertGt(didExpiration, block.timestamp);
    assertLt(didExpiration, block.timestamp + Fixtures.DID_MAX_EXPIRATION_PERIOD + Fixtures.TEST_EXPIRATION_BUFFER);

    // Verify VM expiration is set correctly (1 year)
    uint256 vmExpiration =
      didManagerNative.getExpiration(result.didInfo.methods, result.didInfo.id, DEFAULT_VM_ID_NATIVE);
    assertGt(vmExpiration, block.timestamp);
    assertLt(vmExpiration, block.timestamp + Fixtures.VM_DEFAULT_EXPIRATION_PERIOD + Fixtures.TEST_EXPIRATION_BUFFER);

    _stopPrank();
  }

  function test_CreateDid_Should_CreateWithCustomMethods_When_CustomMethodsProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory result = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.CUSTOM_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0)
    );

    assertEq(result.didInfo.methods, Fixtures.CUSTOM_DID_METHODS);
    assertNotEq(result.didInfo.id, bytes32(0));

    _stopPrank();
  }

  function test_RevertWhen_CreateDid_WithEmptyRandom() public {
    _startPrank(user1);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.createDid(bytes32(0), bytes32(0), bytes32(0));
    _stopPrank();
  }

  function test_RevertWhen_CreateDid_WithDuplicateDidAlreadyExists() public {
    _startPrank(user1);

    // Create first DID
    didManagerNative.createDid(bytes32(0), Fixtures.DEFAULT_RANDOM_0, bytes32(0));

    // Attempt to create duplicate should revert
    vm.expectRevert(DidAlreadyExists.selector);
    didManagerNative.createDid(bytes32(0), Fixtures.DEFAULT_RANDOM_0, bytes32(0));

    _stopPrank();
  }

  // =========================================================================
  // CREATE VM TESTS
  // =========================================================================

  function test_CreateVm_Should_CreateVerificationMethod_When_ValidParametersProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    DidTestHelpersNative.CreateVmResult memory vmResult =
      DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_CUSTOM);

    assertNotEq(vmResult.vmCreatedIdHash, bytes32(0));
    assertEq(vmResult.vmCreatedId, Fixtures.VM_ID_CUSTOM);

    // Verify VM exists and has correct data
    VerificationMethod memory createdVm =
      didManagerNative.getVm(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.VM_ID_CUSTOM, 0);
    assertEq(createdVm.ethereumAddress, Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS);
    assertEq(createdVm.relationships, Fixtures.DEFAULT_VM_RELATIONSHIPS);

    _stopPrank();
  }

  function test_CreateVm_Should_RevertWithDidExpired_When_SenderDidIsExpired() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Warp past DID expiration
    DidTestHelpersNative.warpToFuture(vm, Fixtures.WARP_TO_EXPIRE_DID);

    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(DidExpired.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  function test_CreateVm_Should_RevertWithNotAuthenticated_When_SenderNotAuthenticated() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    _stopPrank();

    // Try creating VM as different user (not authenticated)
    _startPrank(user2);

    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(NotAuthenticatedAsSenderId.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  function test_RevertWhen_CreateVm_WithEmptyMethods() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    CreateVmCommand memory command = CreateVmCommand({
      methods: bytes32(0),
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  function test_RevertWhen_CreateVm_WithEmptyRelationships() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: bytes1(0)
    });

    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  // =========================================================================
  // VALIDATE VM TESTS
  // =========================================================================

  function test_ValidateVm_Should_SetExpiration_When_ValidPositionHashProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    // Create a VM that needs validation
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);

    _stopPrank();

    // Validate as user2 (the ethereumAddress of the VM)
    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    // Verify the VM is now validated
    VerificationMethod memory validatedVm =
      didManagerNative.getVm(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.VM_ID_TEST_1, 0);
    assertGt(validatedVm.expiration, 0);
  }

  function test_RevertWhen_ValidateVm_WithInvalidSender() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);

    _stopPrank();

    // Try to validate as user3 (wrong sender)
    _startPrank(user3);
    vm.expectRevert(IVMStorageNative.InvalidSignature.selector);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();
  }

  // =========================================================================
  // EXPIRE VM TESTS
  // =========================================================================

  function test_ExpireVm_Should_RevertWithMissingParameter_When_MethodsIsZero() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.expireVm(bytes32(0), didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, bytes32(0));
    _stopPrank();
  }

  function test_ExpireVm_Should_RevertWithMissingParameter_When_SenderIdIsZero() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.expireVm(
      didResult.didInfo.methods, bytes32(0), DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, bytes32(0)
    );
    _stopPrank();
  }

  function test_ExpireVm_Should_RevertWithMissingParameter_When_TargetIdIsZero() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.expireVm(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes32(0), bytes32(0)
    );
    _stopPrank();
  }

  // =========================================================================
  // DEACTIVATE DID TESTS
  // =========================================================================

  function test_DeactivateDid_Should_SetExpirationToZero_When_ValidParametersProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );

    uint256 exp = didManagerNative.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0));
    assertEq(exp, 0);

    _stopPrank();
  }

  function test_DeactivateDid_Should_AllowOwnerToDeactivate_When_NoControllersSet() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Owner deactivates their own DID
    vm.recordLogs();
    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );
    Vm.Log[] memory entries = vm.getRecordedLogs();

    // Verify DidDeactivated event emitted
    assertEq(entries[0].topics[1], didResult.didInfo.idHash);

    _stopPrank();
  }

  function test_DeactivateDid_Should_FailAuthentication_When_Deactivated() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );

    // Authentication should fail after deactivation
    vm.expectRevert(DidExpired.selector);
    didManagerNative.authenticate(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, user1);

    _stopPrank();
  }

  function test_RevertWhen_DeactivateDid_WithEmptyMethods() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.deactivateDid(bytes32(0), didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id);
    _stopPrank();
  }

  function test_RevertWhen_DeactivateDid_WithEmptySenderId() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.deactivateDid(
      didResult.didInfo.methods, bytes32(0), DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );
    _stopPrank();
  }

  function test_RevertWhen_DeactivateDid_WithEmptyTargetId() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes32(0)
    );
    _stopPrank();
  }

  // =========================================================================
  // REACTIVATE DID TESTS
  // =========================================================================

  function test_ReactivateDid_Should_ReactivateOwnDid_When_OwnerSelfReactivates() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Deactivate
    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );
    assertEq(didManagerNative.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0)), 0);

    // Reactivate
    didManagerNative.reactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );

    // Verify expiration is set again
    uint256 exp = didManagerNative.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0));
    assertGt(exp, block.timestamp);

    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithActiveDid() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Try to reactivate a DID that is not deactivated
    vm.expectRevert(DidNotDeactivated.selector);
    didManagerNative.reactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );

    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithEmptyMethods() public {
    _startPrank(user1);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.reactivateDid(bytes32(0), bytes32("id"), DEFAULT_VM_ID_NATIVE, bytes32("id"));
    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithEmptySenderId() public {
    _startPrank(user1);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.reactivateDid(DEFAULT_DID_METHODS, bytes32(0), DEFAULT_VM_ID_NATIVE, bytes32("id"));
    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithEmptyTargetId() public {
    _startPrank(user1);
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.reactivateDid(DEFAULT_DID_METHODS, bytes32("id"), DEFAULT_VM_ID_NATIVE, bytes32(0));
    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithInvalidVm() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Deactivate
    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );

    // Try reactivate with wrong VM ID
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.reactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, bytes32(0), didResult.didInfo.id
    );

    _stopPrank();
  }

  // =========================================================================
  // UPDATE CONTROLLER TESTS
  // =========================================================================

  function test_UpdateController_Should_SetController_When_ValidParametersProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create a second DID for the controller
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // Set controller
    didManagerNative.updateController(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );

    // Verify controller
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers =
      didManagerNative.getControllerList(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(controllers[0].id, controllerDid.didInfo.id);

    _stopPrank();
  }

  function test_UpdateController_Should_RemoveController_When_ControllerIdIsZero() public {
    // Create owner DID
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    // Create controller DID
    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Owner adds controller at position 0
    _startPrank(user1);
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    // Controller removes itself by setting controllerId to bytes32(0)
    _startPrank(user2);
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      controllerDid.didInfo.id, // sender is the controller
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id, // target is the owner's DID
      bytes32(0),
      bytes32(0),
      0
    );
    _stopPrank();

    Controller[CONTROLLERS_MAX_LENGTH] memory controllers =
      didManagerNative.getControllerList(ownerDid.didInfo.methods, ownerDid.didInfo.id);
    assertEq(controllers[0].id, bytes32(0));
  }

  function test_UpdateController_Should_UseLastPosition_When_PositionExceedsMax() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // Set controller at invalid position (should clamp to CONTROLLERS_MAX_LENGTH - 1)
    didManagerNative.updateController(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      Fixtures.INVALID_CONTROLLER_POSITION
    );

    Controller[CONTROLLERS_MAX_LENGTH] memory controllers =
      didManagerNative.getControllerList(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(controllers[CONTROLLERS_MAX_LENGTH - 1].id, controllerDid.didInfo.id);

    _stopPrank();
  }

  // =========================================================================
  // AUTHENTICATE TESTS
  // =========================================================================

  function test_Authenticate_Should_ReturnTrue_When_ValidVmProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    bool isAuth =
      didManagerNative.authenticate(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, user1);
    assertTrue(isAuth);

    _stopPrank();
  }

  function test_Authenticate_Should_RevertWithVmAlreadyExpired_When_NonExistentVmProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    vm.expectRevert(IVMStorageNative.VmAlreadyExpired.selector);
    didManagerNative.authenticate(
      didResult.didInfo.methods, didResult.didInfo.id, Fixtures.VM_ID_CUSTOM, user1
    );

    _stopPrank();
  }

  // =========================================================================
  // IS VM RELATIONSHIP TESTS
  // =========================================================================

  function test_IsVmRelationship_Should_ReturnTrue_When_ValidRelationshipExists() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    bool result = didManagerNative.isVmRelationship(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes1(0x01), user1
    );
    assertTrue(result);

    _stopPrank();
  }

  function test_IsVmRelationship_Should_ReturnFalse_When_RelationshipDoesNotExist() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Default VM has only authentication (0x01), not assertion method (0x02)
    bool result = didManagerNative.isVmRelationship(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes1(0x02), user1
    );
    assertFalse(result);

    _stopPrank();
  }

  // =========================================================================
  // GET VM TESTS
  // =========================================================================

  function test_GetVm_Should_ReturnCorrectVm_When_ValidIdProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    VerificationMethod memory retrievedVm =
      didManagerNative.getVm(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, 0);

    assertEq(retrievedVm.ethereumAddress, user1);
    assertEq(retrievedVm.relationships, Fixtures.DEFAULT_VM_RELATIONSHIPS);
    assertGt(retrievedVm.expiration, 0);

    _stopPrank();
  }

  function test_GetVm_Should_ReturnCorrectVm_When_ValidPositionProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    VerificationMethod memory retrievedVm =
      didManagerNative.getVm(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0), 1);

    assertEq(retrievedVm.ethereumAddress, user1);
    assertEq(retrievedVm.relationships, Fixtures.DEFAULT_VM_RELATIONSHIPS);

    _stopPrank();
  }

  function test_GetVm_Should_ReturnEmptyVm_When_InvalidPositionProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    VerificationMethod memory retrievedVm =
      didManagerNative.getVm(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0), 99);

    DidTestHelpersNative.assertEmptyVm(retrievedVm);

    _stopPrank();
  }

  function test_GetVmListLength_Should_ReturnCorrectCount_When_VmsExist() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    uint8 length = didManagerNative.getVmListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(length, 1); // createDid creates one default VM

    _stopPrank();
  }

  function test_GetVmListLength_Should_ReturnZero_When_DidDoesNotExist() public {
    uint8 length = didManagerNative.getVmListLength(DEFAULT_DID_METHODS, bytes32("nonexistent"));
    assertEq(length, 0);
  }

  // =========================================================================
  // GET VM ID AT POSITION TESTS
  // =========================================================================

  function test_GetVmIdAtPosition_Should_ReturnCorrectId_When_ValidPositionProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    bytes32 vmId = didManagerNative.getVmIdAtPosition(didResult.didInfo.methods, didResult.didInfo.id, 1);
    assertEq(vmId, DEFAULT_VM_ID_NATIVE);

    _stopPrank();
  }

  function test_GetVmIdAtPosition_Should_ReturnZero_When_InvalidPositionProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    bytes32 vmId = didManagerNative.getVmIdAtPosition(didResult.didInfo.methods, didResult.didInfo.id, 99);
    assertEq(vmId, bytes32(0));

    _stopPrank();
  }

  // =========================================================================
  // GET EXPIRATION TESTS
  // =========================================================================

  function test_GetExpiration_Should_ReturnCorrectTimestamp_When_DidExists() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    uint256 exp = didManagerNative.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0));
    assertGt(exp, block.timestamp);
    assertLt(exp, block.timestamp + Fixtures.DID_MAX_EXPIRATION_PERIOD + Fixtures.TEST_EXPIRATION_BUFFER);

    _stopPrank();
  }

  function test_GetExpiration_Should_ReturnZero_When_DidDoesNotExist() public {
    uint256 exp = didManagerNative.getExpiration(DEFAULT_DID_METHODS, bytes32("nonexistent"), bytes32(0));
    assertEq(exp, 0);
  }

  // =========================================================================
  // SERVICE TESTS
  // =========================================================================

  function test_UpdateService_Should_CreateAndRetrieve_When_ValidParametersProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );

    // Verify service exists
    uint8 length = didManagerNative.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(length, 1);

    _stopPrank();
  }

  // =========================================================================
  // CONTROLLER DELEGATION TESTS
  // =========================================================================

  function test_ControllerDelegation_Should_AllowControllerToModifyTarget_When_ControllerIsSet() public {
    _startPrank(user1);

    // Create two DIDs
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    _stopPrank();
    _startPrank(user2);

    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    _stopPrank();
    _startPrank(user1);

    // Set user2's DID as controller of user1's DID
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );

    _stopPrank();
    _startPrank(user2);

    // Controller creates a VM on owner's DID
    CreateVmCommand memory command = CreateVmCommand({
      methods: ownerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: ownerDid.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: user3,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    didManagerNative.createVm(command);

    // Verify VM was created on owner's DID
    uint8 vmCount = didManagerNative.getVmListLength(ownerDid.didInfo.methods, ownerDid.didInfo.id);
    assertEq(vmCount, 2); // Initial VM + controller-created VM

    _stopPrank();
  }

  function test_RevertWhen_NonControllerTriesToModifyTarget() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    _stopPrank();
    _startPrank(user2);

    DidTestHelpersNative.CreateDidResult memory nonControllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // Non-controller tries to create VM on owner's DID
    CreateVmCommand memory command = CreateVmCommand({
      methods: ownerDid.didInfo.methods,
      senderId: nonControllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: ownerDid.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: user3,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(NotAControllerforTargetId.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  // =========================================================================
  // CONTROLLER REACTIVATION TESTS (covers else branch in reactivateDid)
  // =========================================================================

  function test_ReactivateDid_Should_AllowControllerToReactivate_When_ControllerIsActive() public {
    // Create owner DID
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    // Create controller DID
    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Owner sets controller
    _startPrank(user1);
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
    _stopPrank();

    // Controller deactivates the DID (once controllers are set, only controllers can act)
    _startPrank(user2);
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();

    // Controller reactivates the DID
    _startPrank(user2);
    didManagerNative.reactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();

    // Verify reactivated
    uint256 exp = didManagerNative.getExpiration(ownerDid.didInfo.methods, ownerDid.didInfo.id, bytes32(0));
    assertGt(exp, block.timestamp);
  }

  function test_RevertWhen_ReactivateDid_WithExpiredControllerDid() public {
    // Create owner DID
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    // Create controller DID
    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Owner sets controller
    _startPrank(user1);
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
    _stopPrank();

    // Controller deactivates the DID
    _startPrank(user2);
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();

    // Warp past controller DID expiration
    DidTestHelpersNative.warpToFuture(vm, Fixtures.WARP_TO_EXPIRE_DID);

    // Controller tries to reactivate but their DID is expired
    _startPrank(user2);
    vm.expectRevert(DidExpired.selector);
    didManagerNative.reactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithUnauthenticatedController() public {
    // Create owner DID
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    // Create controller DID as user2
    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Owner sets controller
    _startPrank(user1);
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
    _stopPrank();

    // Controller deactivates the DID
    _startPrank(user2);
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();

    // user3 tries to reactivate using controller's DID (not authenticated)
    _startPrank(user3);
    vm.expectRevert(NotAuthenticatedAsSenderId.selector);
    didManagerNative.reactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();
  }

  function test_RevertWhen_ReactivateDid_WithNonControllerSender() public {
    // Create owner DID
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Deactivate (no controllers set, so owner can deactivate)
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, ownerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();

    // Create non-controller DID
    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory nonControllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // Non-controller tries to reactivate
    vm.expectRevert(NotAControllerforTargetId.selector);
    didManagerNative.reactivateDid(
      ownerDid.didInfo.methods, nonControllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();
  }

  // =========================================================================
  // VM STORAGE EDGE CASE TESTS (covers VMStorageNative branches)
  // =========================================================================

  function test_CreateVm_Should_RevertWithEthereumAddressRequired_When_AddressIsZero() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: address(0),
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(IVMStorageNative.EthereumAddressRequired.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  function test_RevertWhen_CreateVm_WithDuplicateVmId() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create first VM
    DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_CUSTOM);
    _stopPrank();

    // Try creating VM with same ID
    _startPrank(user1);
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: user2,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(IVMStorageNative.VmAlreadyExists.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }

  function test_ValidateVm_Should_RevertWithVmNotFound_When_InvalidPositionHashProvided() public {
    _startPrank(user1);
    vm.expectRevert(IVMStorageNative.VmNotFound.selector);
    didManagerNative.validateVm(bytes32("invalid"), 0);
    _stopPrank();
  }

  function test_RevertWhen_ValidateVm_AlreadyValidated() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    // Create a VM
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();

    // Validate once
    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);

    // Try validating again
    vm.expectRevert(IVMStorageNative.VmAlreadyValidated.selector);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();
  }

  function test_ExpireVm_Should_ExpireVm_When_ValidParametersProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create and validate a VM
    DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_CUSTOM);
    _stopPrank();

    // Expire it
    _startPrank(user1);
    didManagerNative.expireVm(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_ID_CUSTOM
    );

    // Verify expired
    VerificationMethod memory expiredVm =
      didManagerNative.getVm(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.VM_ID_CUSTOM, 0);
    assertEq(expiredVm.expiration, uint88(block.timestamp));

    _stopPrank();
  }

  function test_RevertWhen_ExpireVm_AlreadyExpired() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_CUSTOM);
    _stopPrank();

    // Expire it
    _startPrank(user1);
    didManagerNative.expireVm(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_ID_CUSTOM
    );

    // Try expiring again
    vm.expectRevert(IVMStorageNative.VmAlreadyExpired.selector);
    didManagerNative.expireVm(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_ID_CUSTOM
    );

    _stopPrank();
  }

  function test_CreateDidWithExistingData_Should_RemoveAllPreviousData_When_HashCollides() public {
    _startPrank(user1);

    // Create DID
    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Add a VM and service
    DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_CUSTOM);
    _stopPrank();

    _startPrank(user1);
    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );

    // Warp past expiration so the DID can be recreated
    DidTestHelpersNative.warpToFuture(vm, Fixtures.WARP_TO_EXPIRE_DID);

    // Re-create DID with same params (triggers _removeAllVms and _removeAllServices)
    didManagerNative.createDid(Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0));

    // Verify old data cleaned: only 1 VM (the new default)
    uint8 vmCount = didManagerNative.getVmListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(vmCount, 1);

    _stopPrank();
  }

  function test_IsVmRelationship_Should_RevertWithMissingParameter_When_ZeroValuesProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Zero sender address
    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.isVmRelationship(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes1(0x01), address(0)
    );

    _stopPrank();
  }

  function test_IsVmRelationship_Should_RevertWithOutOfRange_When_InvalidRelationshipProvided() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    vm.expectRevert(IVMStorageNative.VmRelationshipOutOfRange.selector);
    didManagerNative.isVmRelationship(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes1(0x20), user1
    );

    _stopPrank();
  }

  // =========================================================================
  // DEACTIVATE DID EDGE CASES
  // =========================================================================

  function test_DeactivateDid_Should_AllowControllerToDeactivate_When_ControllerIsSet() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Owner sets controller
    _startPrank(user1);
    didManagerNative.updateController(
      ownerDid.didInfo.methods,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      ownerDid.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
    _stopPrank();

    // Controller deactivates owner's DID
    _startPrank(user2);
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, controllerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();

    uint256 exp = didManagerNative.getExpiration(ownerDid.didInfo.methods, ownerDid.didInfo.id, bytes32(0));
    assertEq(exp, 0);
  }

  function test_RevertWhen_DeactivateDid_WithExpiredSenderDid() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory otherDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();

    // Warp past expiration
    DidTestHelpersNative.warpToFuture(vm, Fixtures.WARP_TO_EXPIRE_DID);

    _startPrank(user2);
    vm.expectRevert(DidExpired.selector);
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, otherDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();
  }

  function test_RevertWhen_DeactivateDid_WithUnauthorizedSender() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory otherDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // user2 tries to deactivate user1's DID but isn't a controller
    vm.expectRevert(NotAControllerforTargetId.selector);
    didManagerNative.deactivateDid(
      ownerDid.didInfo.methods, otherDid.didInfo.id, DEFAULT_VM_ID_NATIVE, ownerDid.didInfo.id
    );
    _stopPrank();
  }

  function test_ReactivateDid_Should_RevertWithNotAuthenticated_When_SelfReactivateWithWrongVm() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Deactivate
    didManagerNative.deactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id
    );

    // Try self-reactivation with a VM ID that doesn't exist (but is non-zero to avoid MissingRequiredParameter)
    vm.expectRevert(NotAuthenticatedAsSenderId.selector);
    didManagerNative.reactivateDid(
      didResult.didInfo.methods, didResult.didInfo.id, Fixtures.VM_ID_CUSTOM, didResult.didInfo.id
    );

    _stopPrank();
  }

  function test_IsVmRelationship_Should_RevertWithMissingParameter_When_RelationshipIsZero() public {
    _startPrank(user1);

    DidTestHelpersNative.CreateDidResult memory didResult =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    vm.expectRevert(IVMStorageNative.MissingRequiredParameter.selector);
    didManagerNative.isVmRelationship(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, bytes1(0), user1
    );

    _stopPrank();
  }

  function test_CreateVm_Should_RevertWithDidExpired_When_TargetDidIsExpired() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory ownerDid =
      DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory otherDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    // Set user1's DID as controller of user2's DID
    didManagerNative.updateController(
      otherDid.didInfo.methods,
      otherDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      otherDid.didInfo.id,
      ownerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
    _stopPrank();

    // Deactivate user2's DID
    _startPrank(user1);
    didManagerNative.deactivateDid(
      otherDid.didInfo.methods, ownerDid.didInfo.id, DEFAULT_VM_ID_NATIVE, otherDid.didInfo.id
    );

    // user1 tries to create VM on deactivated DID
    CreateVmCommand memory command = CreateVmCommand({
      methods: otherDid.didInfo.methods,
      senderId: ownerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: otherDid.didInfo.id,
      vmId: Fixtures.VM_ID_CUSTOM,
      ethereumAddress: user3,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS
    });

    vm.expectRevert(DidExpired.selector);
    didManagerNative.createVm(command);

    _stopPrank();
  }
}
