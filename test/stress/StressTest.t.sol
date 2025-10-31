// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { CreateVmCommand, Controller, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";
import { SERVICE_MAX_LENGTH_LIST, SERVICE_MAX_LENGTH } from "@src/ServiceStorage.sol";
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

        for (uint i = 1; i <= maxVms; i++) {
            uint256 gasStart = gasleft();

            CreateVmCommand memory vmCommand = CreateVmCommand({
                methods: didResult.didInfo.methods,
                senderId: didResult.didInfo.id,
                senderVmId: DEFAULT_VM_ID,
                targetId: didResult.didInfo.id,
                vmId: keccak256(abi.encodePacked("stress-vm-", i, block.timestamp, block.prevrandao, address(this))),
                type_: Fixtures.defaultVmType(),
                publicKeyMultibase: Fixtures.emptyVmPublicKey(),
                blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
                ethereumAddress: address(uint160(uint160(user1) + i)),
                relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
                expiration: Fixtures.EMPTY_VM_EXPIRATION
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

        for (uint i = 1; i <= maxServices; i++) {
            uint256 gasStart = gasleft();

            bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory serviceType;
            serviceType[0][0] = bytes32(abi.encodePacked("StressService", i));

            bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory serviceEndpoint;
            serviceEndpoint[0][0] = bytes32(abi.encodePacked("https://stress", i, ".example.com"));

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

        for (uint i = 0; i < controllerCount; i++) {
            console.log("Creating controller DID", i);
            controllerDids[i] = DidTestHelpers.createDid(
                vm, didManager,
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
            primaryDid.didInfo.id,  // Primary DID controls itself
            bytes32(0),
            0  // Position 0
        );
        uint256 gasUsed = gasStart - gasleft();
        totalGasUsed += gasUsed;
        console.log("Set primary DID as self-controller successfully");

        // Then add other controllers
        for (uint i = 0; i < controllerCount; i++) {
            console.log("Setting controller", i + 1);
            gasStart = gasleft();

            didManager.updateController(
                primaryDid.didInfo.methods,
                primaryDid.didInfo.id,
                DEFAULT_VM_ID,
                primaryDid.didInfo.id,
                controllerDids[i].didInfo.id,
                bytes32(0),
                uint8(i + 1)  // Position i+1 (since position 0 is self)
            );

            gasUsed = gasStart - gasleft();
            totalGasUsed += gasUsed;
            console.log("Set controller", i + 1, "successfully");
        }

        console.log("Successfully added", controllerCount, "controllers");
        console.log("Average gas per controller:", totalGasUsed / controllerCount);

        // Debug: Check controller list
        Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(primaryDid.didInfo.methods, primaryDid.didInfo.id);
        for (uint i = 0; i < controllerCount; i++) {
            console.log("Controller", i, "ID:", vm.toString(controllers[i].id));
            console.log("Controller", i, "VM ID:", vm.toString(controllers[i].vmId));
            console.log("Expected controller ID:", vm.toString(controllerDids[i].didInfo.id));
        }

        // Note: DIDs auto-refresh their 4-year expiration on any write operation
        // (createVm, updateController, updateService). This test executes in < 1 second,
        // so no manual expiration management is needed.

        // Verify all controllers are set and authenticated correctly
        for (uint i = 0; i < controllerCount; i++) {
            // Verify user1 can authenticate as each controller DID
            bool canAuthenticate = didManager.authenticate(
                controllerDids[i].didInfo.methods,
                controllerDids[i].didInfo.id,
                DEFAULT_VM_ID,
                user1
            );
            console.log("User1 can authenticate as controller", i, ":", canAuthenticate);
            assertTrue(canAuthenticate, "User1 should be able to authenticate as controller");
        }

        // Verify controller relationships are properly established
        // This tests the core controller system without complex VM creation
        Controller[CONTROLLERS_MAX_LENGTH] memory finalControllers = didManager.getControllerList(primaryDid.didInfo.methods, primaryDid.didInfo.id);

        // Check that position 0 has primary DID (self-controller)
        assertEq(finalControllers[0].id, primaryDid.didInfo.id, "Primary DID should be self-controller");

        // Check that other positions have the controller DIDs
        for (uint i = 0; i < controllerCount; i++) {
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

        // Create service with maximum endpoint complexity
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory largeServiceType;
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory largeServiceEndpoint;

        // Fill arrays to test maximum data handling
        for (uint i = 0; i < SERVICE_MAX_LENGTH_LIST && i < 3; i++) {
            for (uint j = 0; j < SERVICE_MAX_LENGTH && j < 2; j++) {
                largeServiceType[i][j] = bytes32(abi.encodePacked("LargeType", i, "-", j));
                largeServiceEndpoint[i][j] = bytes32(abi.encodePacked("https://large", i, "-", j, ".example.com"));
            }
        }

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
        bytes32[5] memory largeBlockchainAccountId;
        largeBlockchainAccountId[0] = bytes32("eip155:1:0x1234567890abcdef");
        largeBlockchainAccountId[1] = bytes32("additional-chain-info-1");
        largeBlockchainAccountId[2] = bytes32("additional-chain-info-2");

        gasStart = gasleft();
        CreateVmCommand memory largeVmCommand = CreateVmCommand({
            methods: didResult.didInfo.methods,
            senderId: didResult.didInfo.id,
            senderVmId: DEFAULT_VM_ID,
            targetId: didResult.didInfo.id,
            vmId: keccak256(abi.encodePacked("large-vm", block.timestamp, block.prevrandao, address(this))),
            type_: Fixtures.defaultVmType(),
            publicKeyMultibase: Fixtures.defaultVmPublicKey(),
            blockchainAccountId: largeBlockchainAccountId,
            ethereumAddress: address(0), // No ethereum address for this test
            relationships: Fixtures.VM_RELATIONSHIPS_ALL, // All relationships
            expiration: Fixtures.futureTimestamp(365 days)
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
        for (uint userIndex = 1; userIndex <= 3; userIndex++) {
            address currentUser = userIndex == 1 ? user1 : (userIndex == 2 ? user2 : user3);
            _startPrank(currentUser);

            uint256 operationStart = gasleft();

            // Rapid DID creation
            DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDid(
                vm, didManager,
                Fixtures.CUSTOM_DID_METHODS,
                bytes32(abi.encodePacked("rapid-user-", userIndex)),
                DEFAULT_VM_ID
            );

            // Rapid VM addition
            for (uint i = 1; i <= 3; i++) {
                CreateVmCommand memory vmCommand = CreateVmCommand({
                    methods: didResult.didInfo.methods,
                    senderId: didResult.didInfo.id,
                    senderVmId: DEFAULT_VM_ID,
                    targetId: didResult.didInfo.id,
                    vmId: keccak256(abi.encodePacked("rapid-vm-", userIndex, "-", i, block.timestamp, block.prevrandao)),
                    type_: Fixtures.defaultVmType(),
                    publicKeyMultibase: Fixtures.emptyVmPublicKey(),
                    blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
                    ethereumAddress: address(uint160(uint160(currentUser) + i)),
                    relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
                    expiration: Fixtures.EMPTY_VM_EXPIRATION
                });
                DidTestHelpers.createVm(vm, didManager, vmCommand);
            }

            // Rapid service addition
            for (uint i = 1; i <= 2; i++) {
                bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory serviceType;
                serviceType[0][0] = bytes32(abi.encodePacked("RapidService", i));
                bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory serviceEndpoint;
                serviceEndpoint[0][0] = bytes32(abi.encodePacked("https://rapid", i, ".user", userIndex, ".com"));

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
        try didManager.createVm(CreateVmCommand({
            methods: didResult.didInfo.methods,
            senderId: didResult.didInfo.id,
            senderVmId: DEFAULT_VM_ID,
            targetId: didResult.didInfo.id,
            vmId: DEFAULT_VM_ID, // Duplicate ID
            type_: Fixtures.defaultVmType(),
            publicKeyMultibase: Fixtures.emptyVmPublicKey(),
            blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
            ethereumAddress: user1,
            relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
            expiration: Fixtures.EMPTY_VM_EXPIRATION
        })) {
            revert("Should have failed with duplicate VM ID");
        } catch {
            expectedFailures++;
        }

        // 2. Try invalid parameters (should fail gracefully)
        try didManager.createVm(CreateVmCommand({
            methods: bytes32(0), // Invalid methods
            senderId: didResult.didInfo.id,
            senderVmId: DEFAULT_VM_ID,
            targetId: didResult.didInfo.id,
            vmId: bytes32("invalid-vm"),
            type_: Fixtures.defaultVmType(),
            publicKeyMultibase: Fixtures.emptyVmPublicKey(),
            blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
            ethereumAddress: user1,
            relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
            expiration: Fixtures.EMPTY_VM_EXPIRATION
        })) {
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
            publicKeyMultibase: Fixtures.emptyVmPublicKey(),
            blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
            ethereumAddress: user2,
            relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
            expiration: Fixtures.EMPTY_VM_EXPIRATION
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
        assertTrue(didManager.authenticate(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, user1));
        assertTrue(didManager.authenticate(didResult.didInfo.methods, didResult.didInfo.id, validVmCommand.vmId, user2));

        _stopPrank();
    }
}