// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { CreateVmCommand, Controller, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";
import { console } from "forge-std/console.sol";

/**
 * @title StressTest
 * @notice Stress testing and edge case validation for DID Manager
 * @dev Tests system limits and boundary conditions for academic validation
 */
contract StressTest is TestBase {
  using DidTestHelpers for *;

  // Test users
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;
  address private user3 = Fixtures.TEST_USER_3;

  function setUp() public {
    _deployDidManager();
    _setupUser(user1, "user1");
    _setupUser(user2, "user2");
    _setupUser(user3, "user3");
  }

  // =========================================================================
  // MAXIMUM CAPACITY STRESS TESTS
  // =========================================================================

  function test_StressTest_MaximumVms_SystemLimits() public {
    _startPrank(user1);

    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    console.log("=== MAXIMUM VM CAPACITY STRESS TEST ===");

    // Test creating many VMs to validate EnumerableSet efficiency
    uint256 maxVms = Fixtures.STRESS_TEST_VM_LIMIT; // Reasonable limit for gas constraints
    uint256 totalGasUsed = 0;

    for (uint256 i = 1; i <= maxVms; i++) {
      uint256 gasStart = gasleft();

      CreateVmCommand memory vmCommand = CreateVmCommand({
        methods: didResult.didInfo.methods,
        senderId: didResult.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didResult.didInfo.id,
        vmId: keccak256(abi.encodePacked("stress-vm-", i, block.timestamp, block.prevrandao, address(this))),
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
        blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
        ethereumAddress: address(uint160(uint160(user1) + i)),
        relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
        expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
      });

      DidTestHelpers.createVm(vm, didManager, vmCommand);

      uint256 gasUsed = gasStart - gasleft();
      totalGasUsed += gasUsed;

      if (i % 5 == 0) {
        console.log("Created", i, "VMs, avg gas:", totalGasUsed / i);
      }
    }

    // Verify all VMs were created
    uint256 finalVmCount = didManager.getVmListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(finalVmCount, maxVms + 1); // +1 for default VM

    console.log("Successfully created", maxVms, "VMs");
    console.log("Average gas per VM:", totalGasUsed / maxVms);

    _stopPrank();
  }

  function test_StressTest_MaximumServices_SystemLimits() public {
    _startPrank(user1);

    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    console.log("=== MAXIMUM SERVICE CAPACITY STRESS TEST ===");

    // Test creating many services
    uint256 maxServices = Fixtures.STRESS_TEST_SERVICE_LIMIT; // Reasonable limit for gas constraints
    uint256 totalGasUsed = 0;

    for (uint256 i = 1; i <= maxServices; i++) {
      uint256 gasStart = gasleft();

      bytes memory serviceType = abi.encodePacked("StressService", vm.toString(i));
      bytes memory serviceEndpoint = abi.encodePacked("https://stress", vm.toString(i), ".example.com");

      didManager.updateService(
        didResult.didInfo.methods,
        didResult.didInfo.id,
        DEFAULT_VM_ID,
        didResult.didInfo.id,
        keccak256(abi.encodePacked("stress-service-", i, block.timestamp, block.prevrandao)),
        serviceType,
        serviceEndpoint
      );

      uint256 gasUsed = gasStart - gasleft();
      totalGasUsed += gasUsed;

      if (i % 5 == 0) {
        console.log("Created", i, "services, avg gas:", totalGasUsed / i);
      }
    }

    // Verify all services were created
    uint256 finalServiceCount = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(finalServiceCount, maxServices);

    console.log("Successfully created", maxServices, "services");
    console.log("Average gas per service:", totalGasUsed / maxServices);

    _stopPrank();
  }

  // =========================================================================
  // CONTROLLER SYSTEM STRESS TESTS
  // =========================================================================

  function test_StressTest_MaximumControllers_SystemLimits() public {
    _startPrank(user1);

    // Create primary DID
    DidTestHelpers.CreateDidResult memory primaryDid = DidTestHelpers.createDefaultDid(vm, didManager);

    console.log("=== MAXIMUM CONTROLLER CAPACITY STRESS TEST ===");

    // Create limited controller DIDs for stress test
    uint256 controllerCount = Fixtures.STRESS_TEST_CONTROLLER_LIMIT; // Reduced for debugging
    DidTestHelpers.CreateDidResult[] memory controllerDids = new DidTestHelpers.CreateDidResult[](controllerCount);

    for (uint256 i = 0; i < controllerCount; i++) {
      console.log("Creating controller DID", i);
      controllerDids[i] = DidTestHelpers.createDid(
        vm,
        didManager,
        Fixtures.CUSTOM_DID_METHODS,
        keccak256(abi.encodePacked("controller-", i, block.timestamp, block.prevrandao, address(this))),
        DEFAULT_VM_ID
      );
      console.log("Created controller DID", i, ":", vm.toString(controllerDids[i].didInfo.id));
    }

    // Add all controllers to primary DID
    console.log("Adding controllers to primary DID...");
    uint256 totalGasUsed = 0;

    // First, add the primary DID as its own controller (position 0)
    uint256 gasStart = gasleft();
    didManager.updateController(
      primaryDid.didInfo.methods,
      primaryDid.didInfo.id,
      DEFAULT_VM_ID,
      primaryDid.didInfo.id,
      primaryDid.didInfo.id, // Primary DID controls itself
      bytes32(0),
      0 // Position 0
    );
    uint256 gasUsed = gasStart - gasleft();
    totalGasUsed += gasUsed;
    console.log("Set primary DID as self-controller successfully");

    // Then add other controllers
    for (uint256 i = 0; i < controllerCount; i++) {
      console.log("Setting controller", i + 1);
      gasStart = gasleft();

      didManager.updateController(
        primaryDid.didInfo.methods,
        primaryDid.didInfo.id,
        DEFAULT_VM_ID,
        primaryDid.didInfo.id,
        controllerDids[i].didInfo.id,
        bytes32(0),
        uint8(i + 1) // Position i+1 (since position 0 is self)
      );

      gasUsed = gasStart - gasleft();
      totalGasUsed += gasUsed;
      console.log("Set controller", i + 1, "successfully");
    }

    console.log("Successfully added", controllerCount, "controllers");
    console.log("Average gas per controller:", totalGasUsed / controllerCount);

    // Debug: Check controller list
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers =
      didManager.getControllerList(primaryDid.didInfo.methods, primaryDid.didInfo.id);
    for (uint256 i = 0; i < controllerCount; i++) {
      console.log("Controller", i, "ID:", vm.toString(controllers[i].id));
      console.log("Controller", i, "VM ID:", vm.toString(controllers[i].vmId));
      console.log("Expected controller ID:", vm.toString(controllerDids[i].didInfo.id));
    }

    // Note: DIDs auto-refresh their 4-year expiration on any write operation
    // (createVm, updateController, updateService). This test executes in < 1 second,
    // so no manual expiration management is needed.

    // Verify all controllers are set and authenticated correctly
    for (uint256 i = 0; i < controllerCount; i++) {
      // Verify user1 can authenticate as each controller DID
      bool canAuthenticate = didManager.isVmRelationship(
        controllerDids[i].didInfo.methods, controllerDids[i].didInfo.id, DEFAULT_VM_ID, bytes1(0x01), user1
      );
      console.log("User1 can authenticate as controller", i, ":", canAuthenticate);
      assertTrue(canAuthenticate, "User1 should be able to authenticate as controller");
    }

    // Verify controller relationships are properly established
    // This tests the core controller system without complex VM creation
    Controller[CONTROLLERS_MAX_LENGTH] memory finalControllers =
      didManager.getControllerList(primaryDid.didInfo.methods, primaryDid.didInfo.id);

    // Check that position 0 has primary DID (self-controller)
    assertEq(finalControllers[0].id, primaryDid.didInfo.id, "Primary DID should be self-controller");

    // Check that other positions have the controller DIDs
    for (uint256 i = 0; i < controllerCount; i++) {
      assertEq(finalControllers[i + 1].id, controllerDids[i].didInfo.id, "Controller DID should be at correct position");
      assertEq(finalControllers[i + 1].vmId, bytes32(0), "Controller VM ID should be zero (any VM)");
    }

    console.log("Successfully verified", controllerCount, "controllers with proper authentication");

    // Verify the primary DID still has only its default VM (stress test validates controller setup, not VM creation)
    uint256 finalVmCount = didManager.getVmListLength(primaryDid.didInfo.methods, primaryDid.didInfo.id);
    assertEq(finalVmCount, 1, "Primary DID should still have only default VM");

    _stopPrank();
  }

  // =========================================================================
  // BOUNDARY CONDITION STRESS TESTS
  // =========================================================================

  function test_StressTest_LargeDataStructures_PerformanceValidation() public {
    _startPrank(user1);

    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    console.log("=== LARGE DATA STRUCTURE PERFORMANCE TEST ===");

    // Create service with multiple types and endpoints (testing dynamic bytes)
    // Using null byte delimiter as specified in optimization plan
    bytes memory largeServiceType = abi.encodePacked(
      "LargeType0-0",
      "\x00",
      "LargeType0-1",
      "\x00",
      "LargeType1-0",
      "\x00",
      "LargeType1-1",
      "\x00",
      "LargeType2-0",
      "\x00",
      "LargeType2-1"
    );
    bytes memory largeServiceEndpoint = abi.encodePacked(
      "https://large0-0.example.com",
      "\x00",
      "https://large0-1.example.com",
      "\x00",
      "https://large1-0.example.com",
      "\x00",
      "https://large1-1.example.com",
      "\x00",
      "https://large2-0.example.com",
      "\x00",
      "https://large2-1.example.com"
    );

    uint256 gasStart = gasleft();
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      keccak256(abi.encodePacked("large-service", block.timestamp, block.prevrandao)),
      largeServiceType,
      largeServiceEndpoint
    );
    uint256 gasUsed = gasStart - gasleft();

    console.log("Large service creation gas:", gasUsed);

    // Create VM with maximum blockchain account data
    bytes memory largeBlockchainAccountId =
      abi.encodePacked("eip155:1:0x1234567890abcdef", "additional-chain-info-1", "additional-chain-info-2");

    gasStart = gasleft();
    CreateVmCommand memory largeVmCommand = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: keccak256(abi.encodePacked("large-vm", block.timestamp, block.prevrandao, address(this))),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase(),
      blockchainAccountId: largeBlockchainAccountId,
      ethereumAddress: address(0), // No ethereum address for this test
      relationships: Fixtures.VM_RELATIONSHIPS_ALL, // All relationships
      expiration: uint88(Fixtures.futureTimestamp(365 days))
    });
    DidTestHelpers.createVm(vm, didManager, largeVmCommand);
    gasUsed = gasStart - gasleft();

    console.log("Large VM creation gas:", gasUsed);

    _stopPrank();
  }

  // =========================================================================
  // RAPID OPERATION STRESS TESTS
  // =========================================================================

  function test_StressTest_RapidOperations_ConcurrentSimulation() public {
    console.log("=== RAPID OPERATIONS STRESS TEST ===");

    // Simulate rapid operations by different users
    for (uint256 userIndex = 1; userIndex <= 3; userIndex++) {
      address currentUser = userIndex == 1 ? user1 : (userIndex == 2 ? user2 : user3);
      _startPrank(currentUser);

      uint256 operationStart = gasleft();

      // Rapid DID creation
      DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDid(
        vm, didManager, Fixtures.CUSTOM_DID_METHODS, bytes32(abi.encodePacked("rapid-user-", userIndex)), DEFAULT_VM_ID
      );

      // Rapid VM addition
      for (uint256 i = 1; i <= 3; i++) {
        CreateVmCommand memory vmCommand = CreateVmCommand({
          methods: didResult.didInfo.methods,
          senderId: didResult.didInfo.id,
          senderVmId: DEFAULT_VM_ID,
          targetId: didResult.didInfo.id,
          vmId: keccak256(abi.encodePacked("rapid-vm-", userIndex, "-", i, block.timestamp, block.prevrandao)),
          type_: Fixtures.defaultVmType(),
          publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
          blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
          ethereumAddress: address(uint160(uint160(currentUser) + i)),
          relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
          expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
        });
        DidTestHelpers.createVm(vm, didManager, vmCommand);
      }

      // Rapid service addition
      for (uint256 i = 1; i <= 2; i++) {
        bytes memory serviceType = abi.encodePacked("RapidService", vm.toString(i));
        bytes memory serviceEndpoint =
          abi.encodePacked("https://rapid", vm.toString(i), ".user", vm.toString(userIndex), ".com");

        didManager.updateService(
          didResult.didInfo.methods,
          didResult.didInfo.id,
          DEFAULT_VM_ID,
          didResult.didInfo.id,
          keccak256(abi.encodePacked("rapid-service-", userIndex, "-", i, block.timestamp, block.prevrandao)),
          serviceType,
          serviceEndpoint
        );
      }

      uint256 operationGas = operationStart - gasleft();
      console.log("User", userIndex, "complete operation gas:", operationGas);

      // Verify final state
      assertEq(didManager.getVmListLength(didResult.didInfo.methods, didResult.didInfo.id), 4); // 3 + default
      assertEq(didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id), 2);

      _stopPrank();
    }
  }

  // =========================================================================
  // SYSTEM RESILIENCE TESTS
  // =========================================================================

  function test_StressTest_SystemResilience_ErrorRecovery() public {
    _startPrank(user1);

    console.log("=== SYSTEM RESILIENCE STRESS TEST ===");

    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Test system behavior under various error conditions
    uint256 successfulOperations = 0;
    uint256 expectedFailures = 0;

    // 1. Try to create duplicate VMs (should fail)
    try didManager.createVm(
      CreateVmCommand({
        methods: didResult.didInfo.methods,
        senderId: didResult.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didResult.didInfo.id,
        vmId: DEFAULT_VM_ID, // Duplicate ID
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
        blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
        ethereumAddress: user1,
        relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
        expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
      })
    ) {
      revert("Should have failed with duplicate VM ID");
    } catch {
      expectedFailures++;
    }

    // 2. Try invalid parameters (should fail gracefully)
    try didManager.createVm(
      CreateVmCommand({
        methods: bytes32(0), // Invalid methods
        senderId: didResult.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didResult.didInfo.id,
        vmId: bytes32("invalid-vm"),
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
        blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
        ethereumAddress: user1,
        relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
        expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
      })
    ) {
      revert("Should have failed with invalid methods");
    } catch {
      expectedFailures++;
    }

    // 3. Valid operations should still work after failures
    CreateVmCommand memory validVmCommand = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: keccak256(abi.encodePacked("resilience-vm", block.timestamp, block.prevrandao, address(this))),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user2,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, validVmCommand);
    successfulOperations++;

    // Validate the VM to make it usable (since it has an ethereum address)
    _startPrank(user2);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    _startPrank(user1);

    console.log("Expected failures handled:", expectedFailures);
    console.log("Successful operations after errors:", successfulOperations);

    // System should remain fully functional
    assertTrue(
      didManager.isVmRelationship(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, bytes1(0x01), user1)
    );
    assertTrue(
      didManager.isVmRelationship(
        didResult.didInfo.methods, didResult.didInfo.id, validVmCommand.vmId, bytes1(0x01), user2
      )
    );

    _stopPrank();
  }
}
