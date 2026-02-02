// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { CreateVmCommand, Controller, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_DID_METHODS } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";
import { W3CDidDocument, W3CDidInput } from "@src/interfaces/IW3CResolver.sol";

/**
 * @title DidLifecycleIntegrationTest
 * @notice Integration tests for complete DID lifecycle scenarios
 * @dev Tests cross-contract interactions and complex workflows
 */
contract DidLifecycleIntegrationTest is TestBase {
  using DidTestHelpers for *;

  // Test users
  address private alice = Fixtures.TEST_USER_1;
  address private bob = Fixtures.TEST_USER_2;
  address private carol = Fixtures.TEST_USER_3;

  function setUp() public {
    // Deploy contracts (includes w3cResolver from TestBase)
    _deployDidManager();

    // Setup test users
    address[] memory users = new address[](3);
    string[] memory labels = new string[](3);

    users[0] = alice;
    labels[0] = "alice";
    users[1] = bob;
    labels[1] = "bob";
    users[2] = carol;
    labels[2] = "carol";

    _setupUsers(users, labels);
  }

  // =========================================================================
  // COMPLETE DID LIFECYCLE TESTS
  // =========================================================================

  function test_CompleteDidLifecycle_Should_WorkEndToEnd_When_AllStepsExecuted() public {
    // === Phase 1: Alice creates her DID ===
    _startPrank(alice);

    DidTestHelpers.CreateDidResult memory aliceDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, bytes32("alice-random"), bytes32(0));

    // Verify Alice's DID was created
    assertNotEq(aliceDid.didInfo.id, bytes32(0));
    assertEq(aliceDid.didInfo.methods, DEFAULT_DID_METHODS);

    _stopPrank();

    // === Phase 2: Bob creates his DID ===
    _startPrank(bob);

    DidTestHelpers.CreateDidResult memory bobDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, bytes32("bob-random"), bytes32(0));

    assertNotEq(bobDid.didInfo.id, bytes32(0));

    _stopPrank();

    // === Phase 3: Alice adds additional VMs ===
    _startPrank(alice);

    // Add assertion method VM
    {
      CreateVmCommand memory assertionVmCommand = CreateVmCommand({
        methods: aliceDid.didInfo.methods,
        senderId: aliceDid.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: aliceDid.didInfo.id,
        vmId: bytes32("assertion-key"),
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase(),
        blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
        ethereumAddress: alice, // Alice's assertion key
        relationships: Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
        expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
      });

      DidTestHelpers.CreateVmResult memory assertionVmResult =
        DidTestHelpers.createVm(vm, didManager, assertionVmCommand);

      // Validate the assertion VM (alice validates her own VM)
      didManager.validateVm(assertionVmResult.vmCreatedPositionHash, 0);
    }

    // Add key agreement VM
    {
      CreateVmCommand memory keyAgreementVmCommand = CreateVmCommand({
        methods: aliceDid.didInfo.methods,
        senderId: aliceDid.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: aliceDid.didInfo.id,
        vmId: bytes32("key-agreement"),
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
        blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
        ethereumAddress: carol, // Different address for key agreement
        relationships: Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT | Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
        expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
      });

      DidTestHelpers.CreateVmResult memory keyAgreementVmResult =
        DidTestHelpers.createVm(vm, didManager, keyAgreementVmCommand);

      // Validate the key agreement VM (switch to carol to validate)
      _startPrank(carol);
      didManager.validateVm(keyAgreementVmResult.vmCreatedPositionHash, 0);
      _startPrank(alice);
    }

    // Verify Alice now has 3 VMs (initial + 2 new)
    uint256 aliceVmCount = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(aliceVmCount, 3);

    _stopPrank();

    // === Phase 4: Alice adds a service ===
    _startPrank(alice);

    didManager.updateService(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("identity-hub"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      Fixtures.DEFAULT_SERVICE_ENDPOINT
    );

    // Verify service was added
    uint256 serviceCount = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCount, 1);

    _stopPrank();

    // === Phase 5: Alice delegates control to Bob ===
    _startPrank(alice);

    didManager.updateController(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bobDid.didInfo.id,
      bytes32(0), // No specific VM required
      0 // Position 0
    );

    // Verify Bob is now a controller
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers =
      didManager.getControllerList(aliceDid.didInfo.methods, aliceDid.didInfo.id);

    assertEq(controllers[0].id, bobDid.didInfo.id);

    _stopPrank();

    // === Phase 6: Bob uses delegated control ===
    _startPrank(bob);

    // Bob adds a new VM to Alice's DID using his authority
    CreateVmCommand memory bobControlledVmCommand = CreateVmCommand({
      methods: aliceDid.didInfo.methods,
      senderId: bobDid.didInfo.id, // Bob is the sender
      senderVmId: DEFAULT_VM_ID,
      targetId: aliceDid.didInfo.id, // But target is Alice's DID
      vmId: bytes32("bob-controlled-vm"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: bob,
      relationships: Fixtures.VM_RELATIONSHIPS_CAPABILITY_DELEGATION | Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });

    {
      DidTestHelpers.CreateVmResult memory bobControlledVmResult =
        DidTestHelpers.createVm(vm, didManager, bobControlledVmCommand);

      // Validate the bob-controlled VM (bob validates his own VM)
      didManager.validateVm(bobControlledVmResult.vmCreatedPositionHash, 0);
    }

    // Verify Alice now has 4 VMs
    uint256 finalVmCount = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(finalVmCount, 4);

    _stopPrank();

    // === Phase 7: W3C Resolution ===
    // Test that the complete DID can be resolved as W3C-compliant document
    W3CDidInput memory didInput = W3CDidInput({
      methods: aliceDid.didInfo.methods,
      id: aliceDid.didInfo.id,
      fragment: bytes32(0) // Optional fragment
    });

    W3CDidDocument memory w3cDoc = w3cResolver.resolve(didInput, false);

    // Verify W3C document structure
    assertTrue(bytes(w3cDoc.id).length > 0);
    assertTrue(w3cDoc.context.length > 0);
    assertGt(w3cDoc.expiration, block.timestamp);

    // Should have multiple verification methods
    assertTrue(w3cDoc.verificationMethod.length > 0);

    // Should have service endpoint
    assertTrue(w3cDoc.service.length > 0);

    // === Phase 8: Authentication Tests ===
    // Test authentication with different VMs and users

    // Alice can authenticate with her original VM
    assertTrue(didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, alice));

    // Carol can authenticate with the key agreement VM
    assertTrue(didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("key-agreement"), carol));

    // Bob can authenticate with the VM he created
    assertTrue(
      didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("bob-controlled-vm"), bob)
    );

    // === Phase 9: Relationship Testing ===
    // Test that all relationship types work correctly

    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, alice
      )
    );

    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods,
        aliceDid.didInfo.id,
        bytes32("assertion-key"),
        Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
        alice
      )
    );

    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods,
        aliceDid.didInfo.id,
        bytes32("key-agreement"),
        Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,
        carol
      )
    );

    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods,
        aliceDid.didInfo.id,
        bytes32("bob-controlled-vm"),
        Fixtures.VM_RELATIONSHIPS_CAPABILITY_DELEGATION,
        bob
      )
    );
  }

  // =========================================================================
  // MULTI-USER INTERACTION TESTS
  // =========================================================================

  function test_MultiUserInteraction_Should_WorkCorrectly_When_MultipleUsersCollaborate() public {
    // Create DIDs for all users
    _startPrank(alice);
    DidTestHelpers.CreateDidResult memory aliceDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(bob);
    DidTestHelpers.CreateDidResult memory bobDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(carol);
    DidTestHelpers.CreateDidResult memory carolDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // === Scenario: Multi-sig style control ===
    // Alice delegates control to both Bob and Carol

    _startPrank(alice);

    // Add Bob as controller at position 0
    didManager.updateController(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bobDid.didInfo.id,
      bytes32(0),
      0
    );

    _stopPrank();

    // Now Bob (with delegated control) adds Carol as controller at position 1
    _startPrank(bob);
    didManager.updateController(
      aliceDid.didInfo.methods, // Use target's methods (same namespace as controller check)
      bobDid.didInfo.id, // Bob is the sender
      DEFAULT_VM_ID,
      aliceDid.didInfo.id, // Target is Alice's DID
      carolDid.didInfo.id,
      bytes32(0),
      1
    );

    _stopPrank();

    // Verify both controllers are set
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers =
      didManager.getControllerList(aliceDid.didInfo.methods, aliceDid.didInfo.id);

    assertEq(controllers[0].id, bobDid.didInfo.id);
    assertEq(controllers[1].id, carolDid.didInfo.id);

    // === Test: Both controllers can manage Alice's DID ===

    // Bob adds a VM
    _startPrank(bob);
    CreateVmCommand memory bobVmCommand = CreateVmCommand({
      methods: aliceDid.didInfo.methods,
      senderId: bobDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: aliceDid.didInfo.id,
      vmId: bytes32("bob-managed-vm"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: bob,
      relationships: Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD | Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory bobVmResult = DidTestHelpers.createVm(vm, didManager, bobVmCommand);

    // Validate Bob's VM (bob validates his own VM)
    didManager.validateVm(bobVmResult.vmCreatedPositionHash, 0);
    _stopPrank();

    // Carol adds a service
    _startPrank(carol);
    CreateVmCommand memory carolVmCommand = CreateVmCommand({
      methods: aliceDid.didInfo.methods,
      senderId: carolDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: aliceDid.didInfo.id,
      vmId: bytes32("carol-managed-vm"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: carol,
      relationships: Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT | Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory carolVmResult = DidTestHelpers.createVm(vm, didManager, carolVmCommand);

    // Validate Carol's VM (carol validates her own VM)
    didManager.validateVm(carolVmResult.vmCreatedPositionHash, 0);
    _stopPrank();

    // Verify Alice's DID now has VMs from all three users
    uint256 finalVmCount = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(finalVmCount, 3); // Original + Bob's + Carol's

    // All should be able to authenticate with their respective VMs
    assertTrue(didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, alice));
    assertTrue(didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("bob-managed-vm"), bob));
    assertTrue(
      didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("carol-managed-vm"), carol)
    );
  }

  // =========================================================================
  // ERROR RECOVERY AND EDGE CASES
  // =========================================================================

  function test_ErrorRecovery_Should_HandleFailuresGracefully_When_InvalidOperationsAttempted() public {
    _startPrank(alice);

    // Create a valid DID
    DidTestHelpers.CreateDidResult memory aliceDid = DidTestHelpers.createDefaultDid(vm, didManager);

    // === Test: Invalid controller operations ===

    // Try to set non-existent DID as controller (currently allowed by implementation)
    // Note: The current implementation doesn't validate controller DID existence
    didManager.updateController(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("non-existent-did"),
      bytes32(0),
      0
    );

    // === Test: Invalid VM creation ===

    // Try to create VM with empty relationships (should fail)
    CreateVmCommand memory invalidVmCommand = CreateVmCommand({
      methods: aliceDid.didInfo.methods,
      senderId: aliceDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: aliceDid.didInfo.id,
      vmId: bytes32("invalid-vm"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: alice,
      relationships: bytes1(0), // Invalid: empty relationships
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });

    vm.expectRevert();
    didManager.createVm(invalidVmCommand);

    // === Test: Invalid parameter operations ===

    // Try to create DID with empty random (should fail)
    vm.expectRevert();
    didManager.createDid(Fixtures.EMPTY_DID_METHODS, bytes32(0), bytes32(0));

    _stopPrank();

    // Verify the original DID is still intact and functional
    assertTrue(didManager.authenticate(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, alice));

    uint256 vmCount = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(vmCount, 1); // Only the original VM should exist
  }
}
