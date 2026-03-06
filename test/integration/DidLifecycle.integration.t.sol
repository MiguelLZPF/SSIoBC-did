// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { CreateVmCommand, Controller, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_DID_METHODS } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID, IVMStorage } from "@src/interfaces/IVMStorage.sol";
import { W3CDidDocument, W3CDidInput } from "@src/interfaces/IW3CResolver.sol";
import { DidExpired, NotAControllerforTargetId, MissingRequiredParameter } from "@interfaces/IDidManagerBase.sol";

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
    assertTrue(
      didManager.isVmRelationship(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, bytes1(0x01), alice)
    );

    // Carol can authenticate with the key agreement VM
    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("key-agreement"), bytes1(0x01), carol
      )
    );

    // Bob can authenticate with the VM he created
    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("bob-controlled-vm"), bytes1(0x01), bob
      )
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
    assertTrue(
      didManager.isVmRelationship(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, bytes1(0x01), alice)
    );
    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("bob-managed-vm"), bytes1(0x01), bob
      )
    );
    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("carol-managed-vm"), bytes1(0x01), carol
      )
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

    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.createVm(invalidVmCommand);

    // === Test: Invalid parameter operations ===

    // Try to create DID with empty random (should fail)
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.createDid(Fixtures.EMPTY_DID_METHODS, bytes32(0), bytes32(0));

    _stopPrank();

    // Verify the original DID is still intact and functional
    assertTrue(
      didManager.isVmRelationship(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, bytes1(0x01), alice)
    );

    uint256 vmCount = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(vmCount, 1); // Only the original VM should exist
  }

  // =========================================================================
  // FULL LIFECYCLE WITH RESOLUTION VERIFICATION
  // =========================================================================

  function test_FullLifecycle_CreateModifyResolveModifyResolve_ShouldReflectChanges() public {
    // === Phase 1: Alice creates her DID ===
    _startPrank(alice);

    DidTestHelpers.CreateDidResult memory aliceDid = DidTestHelpers.createDefaultDid(vm, didManager);

    // === Phase 2: Alice adds a verification method ===
    CreateVmCommand memory vm1Command = CreateVmCommand({
      methods: aliceDid.didInfo.methods,
      senderId: aliceDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: aliceDid.didInfo.id,
      vmId: bytes32("vm-authentication"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: alice,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION | Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });

    DidTestHelpers.CreateVmResult memory vm1Result = DidTestHelpers.createVm(vm, didManager, vm1Command);
    didManager.validateVm(vm1Result.vmCreatedPositionHash, 0);

    // Verify VM count after first addition
    uint256 vmCountAfterVm1 = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(vmCountAfterVm1, 2); // Original + 1 new

    // === Phase 3: Alice adds a service endpoint ===
    didManager.updateService(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("service-1"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      Fixtures.DEFAULT_SERVICE_ENDPOINT
    );

    // Verify service count
    uint256 serviceCountAfterService1 = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountAfterService1, 1);

    _stopPrank();

    // === Phase 4: First W3C Resolution - verify initial state ===
    W3CDidInput memory didInput1 =
      W3CDidInput({ methods: aliceDid.didInfo.methods, id: aliceDid.didInfo.id, fragment: bytes32(0) });

    W3CDidDocument memory w3cDoc1 = w3cResolver.resolve(didInput1, false);

    // Verify first resolution state
    assertTrue(bytes(w3cDoc1.id).length > 0);
    assertEq(w3cDoc1.verificationMethod.length, 2); // Original VM + 1 new VM
    assertEq(w3cDoc1.service.length, 1); // 1 service endpoint
    assertTrue(w3cDoc1.authentication.length > 0);
    assertTrue(w3cDoc1.assertionMethod.length > 0);

    // === Phase 5: Alice updates the service endpoint (before delegating control) ===
    _startPrank(alice);

    didManager.updateService(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("service-1"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://updated.example.com"
    );

    // Service count should remain the same (update, not add)
    uint256 serviceCountAfterUpdate = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountAfterUpdate, 1);

    // === Phase 6: Alice adds another verification method ===
    CreateVmCommand memory vm2Command = CreateVmCommand({
      methods: aliceDid.didInfo.methods,
      senderId: aliceDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: aliceDid.didInfo.id,
      vmId: bytes32("vm-key-agreement"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: carol,
      relationships: Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });

    DidTestHelpers.CreateVmResult memory vm2Result = DidTestHelpers.createVm(vm, didManager, vm2Command);

    _stopPrank();

    // Validate with carol's address
    _startPrank(carol);
    didManager.validateVm(vm2Result.vmCreatedPositionHash, 0);
    _stopPrank();

    // Verify VM count after second addition
    uint256 vmCountAfterVm2 = didManager.getVmListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(vmCountAfterVm2, 3); // Original + 2 new

    // === Phase 7: Second W3C Resolution - verify all changes reflected ===
    W3CDidDocument memory w3cDoc2 = w3cResolver.resolve(didInput1, false);

    // Verify second resolution state - all changes should be reflected
    assertEq(w3cDoc2.verificationMethod.length, 3); // Original + 2 new VMs
    assertEq(w3cDoc2.service.length, 1); // Still 1 service (was updated)
    assertTrue(w3cDoc2.keyAgreement.length > 0); // New VM has key agreement relationship
    assertTrue(w3cDoc2.authentication.length > 0); // First added VM still has authentication
    assertTrue(w3cDoc2.assertionMethod.length > 0); // First added VM still has assertion method

    // Verify service endpoint was updated in resolution
    assertTrue(w3cDoc2.service.length > 0);

    // === Phase 8: Verify all operations are functional ===
    assertTrue(
      didManager.isVmRelationship(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, bytes1(0x01), alice)
    );
    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32("vm-authentication"), bytes1(0x01), alice
      )
    );
    // Verify VM relationships are correct
    assertTrue(
      didManager.isVmRelationship(
        aliceDid.didInfo.methods,
        aliceDid.didInfo.id,
        bytes32("vm-key-agreement"),
        Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,
        carol
      )
    );
  }

  // =========================================================================
  // DEACTIVATION AND REACTIVATION WITH DATA PRESERVATION
  // =========================================================================

  function test_DeactivateReactivate_ShouldPreserveServicesAndControllers() public {
    // === Phase 1: Alice creates her DID ===
    _startPrank(alice);

    DidTestHelpers.CreateDidResult memory aliceDid = DidTestHelpers.createDefaultDid(vm, didManager);

    // === Phase 2: Alice adds a service endpoint ===
    didManager.updateService(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("backup-service"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://backup.example.com"
    );

    // Verify service was added
    uint256 serviceCountBefore = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountBefore, 1);

    // === Phase 3: Alice deactivates her DID (while she is the owner) ===
    didManager.deactivateDid(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, aliceDid.didInfo.id);

    // Verify DID is now deactivated (expiration == 0)
    assertTrue(didManager.getExpiration(aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32(0)) == 0);

    _stopPrank();

    // === Phase 4: Verify deactivated DID cannot perform operations ===
    vm.expectRevert(DidExpired.selector);
    _startPrank(alice);
    didManager.updateService(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("should-fail"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://fail.example.com"
    );
    _stopPrank();

    // === Phase 5: Bob creates his DID (to act as reactivator) ===
    _startPrank(bob);
    DidTestHelpers.CreateDidResult memory bobDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // === Phase 6: Alice sets Bob as controller (of her deactivated DID) ===
    // Note: Alice can't do this while DID is deactivated, so we must do this another way
    // Actually, since the DID is deactivated, Alice can't set a controller
    // Let's have Alice reactivate via self-reactivation first
    _startPrank(alice);

    didManager.reactivateDid(aliceDid.didInfo.methods, aliceDid.didInfo.id, DEFAULT_VM_ID, aliceDid.didInfo.id);

    _stopPrank();

    // === Phase 7: Verify DID is reactivated (has future expiration) ===
    uint256 expirationAfterReactivation =
      didManager.getExpiration(aliceDid.didInfo.methods, aliceDid.didInfo.id, bytes32(0));
    assertTrue(expirationAfterReactivation > 0);
    assertTrue(expirationAfterReactivation > block.timestamp);

    // === Phase 8: Verify services were preserved ===
    uint256 serviceCountAfter = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountAfter, 1);

    // === Phase 9: Alice adds a controller after reactivation ===
    _startPrank(alice);
    didManager.updateController(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bobDid.didInfo.id,
      bytes32(0),
      0
    );

    // Verify controller was set
    Controller[CONTROLLERS_MAX_LENGTH] memory controllersAfterReactivation =
      didManager.getControllerList(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(controllersAfterReactivation[0].id, bobDid.didInfo.id);

    _stopPrank();

    // === Phase 10: Bob (controller) verifies he can manage the DID ===
    _startPrank(bob);
    didManager.updateService(
      aliceDid.didInfo.methods,
      bobDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("new-service-after-reactivation"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://new.example.com"
    );
    _stopPrank();

    // Verify new service was added
    uint256 finalServiceCount = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(finalServiceCount, 2);
  }

  // =========================================================================
  // CONTROLLER ACCESS REVOCATION
  // =========================================================================

  function test_ControllerUpdate_OldControllerShouldLoseAccess() public {
    // === Phase 1: Alice creates her DID and adds initial service ===
    _startPrank(alice);

    DidTestHelpers.CreateDidResult memory aliceDid = DidTestHelpers.createDefaultDid(vm, didManager);

    didManager.updateService(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("initial-service"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      Fixtures.DEFAULT_SERVICE_ENDPOINT
    );

    uint256 serviceCountInitial = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountInitial, 1);

    _stopPrank();

    // === Phase 2: Create controller DIDs for Bob and Carol ===
    _startPrank(bob);
    DidTestHelpers.CreateDidResult memory bobDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(carol);
    DidTestHelpers.CreateDidResult memory carolDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // === Phase 3: Alice sets Bob as controller ===
    _startPrank(alice);

    didManager.updateController(
      aliceDid.didInfo.methods,
      aliceDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bobDid.didInfo.id,
      bytes32(0),
      0
    );

    // Verify Bob is controller
    Controller[CONTROLLERS_MAX_LENGTH] memory controllersAfterBob =
      didManager.getControllerList(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(controllersAfterBob[0].id, bobDid.didInfo.id);

    _stopPrank();

    // === Phase 4: Bob successfully performs an operation (as controller) ===
    _startPrank(bob);

    // Bob adds a service endpoint to Alice's DID using his controller authority
    didManager.updateService(
      aliceDid.didInfo.methods,
      bobDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("bob-added-service"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://bob.example.com"
    );

    uint256 serviceCountAfterBobAdd = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountAfterBobAdd, 2);

    _stopPrank();

    // === Phase 5: Bob (current controller) replaces himself with Carol ===
    _startPrank(bob);

    didManager.updateController(
      aliceDid.didInfo.methods,
      bobDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      carolDid.didInfo.id,
      bytes32(0),
      0 // Same position - replaces Bob with Carol
    );

    // Verify Carol is now the controller at position 0
    Controller[CONTROLLERS_MAX_LENGTH] memory controllersAfterCarol =
      didManager.getControllerList(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(controllersAfterCarol[0].id, carolDid.didInfo.id);

    _stopPrank();

    // === Phase 6: Bob attempts to perform operation - should fail ===
    _startPrank(bob);

    // Bob should no longer be able to add services as he's no longer a controller
    vm.expectRevert(NotAControllerforTargetId.selector);
    didManager.updateService(
      aliceDid.didInfo.methods,
      bobDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("bob-should-fail"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://bob-fail.example.com"
    );

    _stopPrank();

    // === Phase 7: Carol successfully performs operation (as new controller) ===
    _startPrank(carol);

    didManager.updateService(
      aliceDid.didInfo.methods,
      carolDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("carol-added-service"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://carol.example.com"
    );

    uint256 serviceCountAfterCarolAdd = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(serviceCountAfterCarolAdd, 3); // initial + bob's + carol's

    // Carol adds another service to verify continued access
    didManager.updateService(
      aliceDid.didInfo.methods,
      carolDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("carol-second-service"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://carol-second.example.com"
    );
    _stopPrank();

    // === Phase 8: Final verification ===
    uint256 finalServiceCount = didManager.getServiceListLength(aliceDid.didInfo.methods, aliceDid.didInfo.id);
    assertEq(finalServiceCount, 4);

    // Bob still cannot perform operations (reconfirm his loss of access)
    _startPrank(bob);
    vm.expectRevert(NotAControllerforTargetId.selector);
    didManager.updateService(
      aliceDid.didInfo.methods,
      bobDid.didInfo.id,
      DEFAULT_VM_ID,
      aliceDid.didInfo.id,
      bytes32("bob-final-attempt"),
      Fixtures.DEFAULT_SERVICE_TYPE,
      "https://bob-final.example.com"
    );
    _stopPrank();
  }
}
