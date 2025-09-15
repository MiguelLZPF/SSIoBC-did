// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { IDidManager } from "@src/interfaces/IDidManager.sol";
import { Service, SERVICE_MAX_LENGTH_LIST, SERVICE_MAX_LENGTH } from "@src/ServiceStorage.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";
import { Vm } from "forge-std/Vm.sol";

/**
 * @title ServiceStorageUnitTest
 * @notice Unit tests for service storage functionality in DidManager
 * @dev Tests service creation, updates, deletion, and retrieval
 */
contract ServiceStorageUnitTest is TestBase {
    using DidTestHelpers for *;

    // Test users
    address private admin = Fixtures.TEST_USER_ADMIN;
    address private user1 = Fixtures.TEST_USER_1;
    address private user2 = Fixtures.TEST_USER_2;

    function setUp() public {
        // Deploy contracts
        _deployDidManager();

        // Setup test users
        address[] memory users = new address[](3);
        string[] memory labels = new string[](3);

        users[0] = admin;
        labels[0] = "admin";
        users[1] = user1;
        labels[1] = "user1";
        users[2] = user2;
        labels[2] = "user2";

        _setupUsers(users, labels);
    }

    // =========================================================================
    // SERVICE CREATION TESTS
    // =========================================================================

    function test_UpdateService_Should_CreateService_When_ValidParametersProvided() public {
        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Create a service
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Verify: Service was created
        uint256 serviceLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(serviceLength, 1);

        // Verify: Service details are correct
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            0 // position not used when serviceId is provided
        );

        assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
        assertEq(service.type_[0][0], bytes32("LinkedDomains"));
        assertEq(service.serviceEndpoint[0][0], bytes32("https://bar.example.com"));

        _stopPrank();
    }

    function test_UpdateService_Should_UpdateExistingService_When_ServiceExists() public {
        _startPrank(user1);

        // Setup: Create a DID and initial service
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
        
        // Create initial service
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Test: Update the service with new data
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory newServiceType;
        newServiceType[0][0] = bytes32("UpdatedServiceType");
        
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory newServiceEndpoint;
        newServiceEndpoint[0][0] = bytes32("https://updated.example.com");

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            newServiceType,
            newServiceEndpoint
        );

        // Verify: Service was updated (still only 1 service)
        uint256 serviceLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(serviceLength, 1);

        // Verify: Service details are updated
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            0
        );

        assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
        assertEq(service.type_[0][0], bytes32("UpdatedServiceType"));
        assertEq(service.serviceEndpoint[0][0], bytes32("https://updated.example.com"));

        _stopPrank();
    }

    function test_UpdateService_Should_CreateMultipleServices_When_DifferentIdsProvided() public {
        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Create first service
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Test: Create second service
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory service2Type;
        service2Type[0][0] = bytes32("SecondServiceType");
        
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory service2Endpoint;
        service2Endpoint[0][0] = bytes32("https://service2.example.com");

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.SERVICE_ID_TEST_1,
            service2Type,
            service2Endpoint
        );

        // Verify: Both services exist
        uint256 serviceLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(serviceLength, 2);

        // Verify: First service details
        Service memory service1 = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            0
        );
        assertEq(service1.id, Fixtures.DEFAULT_SERVICE_ID);
        assertEq(service1.type_[0][0], bytes32("LinkedDomains"));

        // Verify: Second service details
        Service memory service2 = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.SERVICE_ID_TEST_1,
            0
        );
        assertEq(service2.id, Fixtures.SERVICE_ID_TEST_1);
        assertEq(service2.type_[0][0], bytes32("SecondServiceType"));

        _stopPrank();
    }

    function test_RevertWhen_UpdateService_WithEmptyServiceId() public {
        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Try to create service with empty ID
        vm.expectRevert();
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            bytes32(0), // Empty service ID
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        _stopPrank();
    }

    function test_RevertWhen_UpdateService_WithEmptyServiceType() public {
        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Try to create service with empty type
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyType;
        // emptyType is already initialized to all zeros
        
        vm.expectRevert();
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            emptyType, // Empty service type
            Fixtures.defaultServiceEndpoint()
        );

        _stopPrank();
    }

    function test_RevertWhen_UpdateService_WithEmptyServiceEndpoint() public {
        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Try to create service with empty endpoint
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyEndpoint;
        // emptyEndpoint is already initialized to all zeros
        
        vm.expectRevert();
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            emptyEndpoint // Empty service endpoint
        );

        _stopPrank();
    }

    // =========================================================================
    // SERVICE DELETION TESTS
    // =========================================================================

    function test_UpdateService_Should_DeleteService_When_EmptyTypeAndEndpointProvided() public {
        _startPrank(user1);

        // Setup: Create a DID and service
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
        
        // Create service first
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Verify service exists
        uint256 initialLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(initialLength, 1);

        // Test: Delete service by providing empty type and endpoint arrays
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyType;
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyEndpoint;
        // Both are already initialized to all zeros

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            emptyType,
            emptyEndpoint
        );

        // Verify: Service was deleted
        uint256 finalLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(finalLength, 0);

        _stopPrank();
    }

    function test_UpdateService_Should_HandleMultipleServiceDeletion_When_ServicesExist() public {
        _startPrank(user1);

        // Setup: Create a DID and multiple services
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
        
        // Create first service
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Create second service
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory service2Type;
        service2Type[0][0] = bytes32("SecondServiceType");
        
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory service2Endpoint;
        service2Endpoint[0][0] = bytes32("https://service2.example.com");

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.SERVICE_ID_TEST_1,
            service2Type,
            service2Endpoint
        );

        // Verify both services exist
        uint256 initialLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(initialLength, 2);

        // Test: Delete first service
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyType;
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyEndpoint;

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            emptyType,
            emptyEndpoint
        );

        // Verify: One service remains
        uint256 afterFirstDeletion = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(afterFirstDeletion, 1);

        // Test: Delete second service
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.SERVICE_ID_TEST_1,
            emptyType,
            emptyEndpoint
        );

        // Verify: No services remain
        uint256 finalLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(finalLength, 0);

        _stopPrank();
    }

    // =========================================================================
    // SERVICE RETRIEVAL TESTS
    // =========================================================================

    function test_GetService_Should_ReturnCorrectService_When_ValidIdProvided() public {
        _startPrank(user1);

        // Setup: Create a DID and service
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
        
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Test: Get service by ID
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            0 // position not used when ID is provided
        );

        // Verify: Correct service returned
        assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
        assertEq(service.type_[0][0], bytes32("LinkedDomains"));
        assertEq(service.serviceEndpoint[0][0], bytes32("https://bar.example.com"));

        _stopPrank();
    }

    function test_GetService_Should_ReturnCorrectService_When_ValidPositionProvided() public {
        _startPrank(user1);

        // Setup: Create a DID and service
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
        
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Test: Get service by position (1-based indexing)
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            bytes32(0), // No specific ID, use position
            1 // First service position (1-based)
        );

        // Verify: Correct service returned
        assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
        assertEq(service.type_[0][0], bytes32("LinkedDomains"));
        assertEq(service.serviceEndpoint[0][0], bytes32("https://bar.example.com"));

        _stopPrank();
    }

    function test_GetService_Should_ReturnEmptyService_When_InvalidPositionProvided() public {
        _startPrank(user1);

        // Setup: Create a DID (no services)
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Get service at invalid position
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            bytes32(0), // No specific ID
            255 // Invalid position (uint8 max)
        );

        // Verify: Empty service returned
        assertEq(service.id, bytes32(0));
        assertEq(service.type_[0][0], bytes32(0));
        assertEq(service.serviceEndpoint[0][0], bytes32(0));

        _stopPrank();
    }

    function test_GetService_Should_ReturnEmptyService_When_NonExistentIdProvided() public {
        _startPrank(user1);

        // Setup: Create a DID (no services)
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Get service with non-existent ID
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            bytes32("non-existent-service"),
            0
        );

        // Verify: Empty service returned
        assertEq(service.id, bytes32(0));
        assertEq(service.type_[0][0], bytes32(0));
        assertEq(service.serviceEndpoint[0][0], bytes32(0));

        _stopPrank();
    }

    // =========================================================================
    // SERVICE LIST LENGTH TESTS
    // =========================================================================

    function test_GetServiceListLength_Should_ReturnCorrectCount_When_ServicesExist() public {
        _startPrank(user1);

        // Setup: Create a DID
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Initially should have 0 services
        uint256 initialLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(initialLength, 0);

        // Add first service
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Test: Service list length should increase
        uint256 afterFirstService = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(afterFirstService, 1);

        // Add second service
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory service2Type;
        service2Type[0][0] = bytes32("SecondServiceType");
        
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory service2Endpoint;
        service2Endpoint[0][0] = bytes32("https://service2.example.com");

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.SERVICE_ID_TEST_1,
            service2Type,
            service2Endpoint
        );

        // Test: Service list length should increase again
        uint256 finalLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(finalLength, 2);

        _stopPrank();
    }

    function test_GetServiceListLength_Should_ReturnZero_When_DidDoesNotExist() public {
        _startPrank(user1);

        // Test: Get service list length for non-existent DID
        uint256 length = didManager.getServiceListLength(
            Fixtures.CUSTOM_DID_METHODS,
            bytes32("non-existent-did")
        );

        // Verify: Length is zero
        assertEq(length, 0);

        _stopPrank();
    }

    function test_GetServiceListLength_Should_DecreaseAfterDeletion_When_ServiceDeleted() public {
        _startPrank(user1);

        // Setup: Create a DID and service
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
        
        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            Fixtures.defaultServiceType(),
            Fixtures.defaultServiceEndpoint()
        );

        // Verify service exists
        uint256 beforeDeletion = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(beforeDeletion, 1);

        // Test: Delete service
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyType;
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory emptyEndpoint;

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            emptyType,
            emptyEndpoint
        );

        // Verify: Service list length decreased
        uint256 afterDeletion = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
        assertEq(afterDeletion, 0);

        _stopPrank();
    }

    // =========================================================================
    // COMPLEX SCENARIOS TESTS
    // =========================================================================

    function test_UpdateService_Should_HandleComplexServiceEndpoints_When_MultipleEndpointsProvided() public {
        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Create service with multiple types and endpoints
        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory multipleTypes;
        multipleTypes[0][0] = bytes32("ServiceType1");
        multipleTypes[1][0] = bytes32("ServiceType2");

        bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory multipleEndpoints;
        multipleEndpoints[0][0] = bytes32("https://endpoint1.example.com");
        multipleEndpoints[1][0] = bytes32("https://endpoint2.example.com");
        multipleEndpoints[2][0] = bytes32("https://endpoint3.example.com");

        didManager.updateService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            multipleTypes,
            multipleEndpoints
        );

        // Verify: Service was created correctly
        Service memory service = didManager.getService(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.DEFAULT_SERVICE_ID,
            0
        );

        assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
        assertEq(service.type_[0][0], bytes32("ServiceType1"));
        assertEq(service.type_[1][0], bytes32("ServiceType2"));
        assertEq(service.serviceEndpoint[0][0], bytes32("https://endpoint1.example.com"));
        assertEq(service.serviceEndpoint[1][0], bytes32("https://endpoint2.example.com"));
        assertEq(service.serviceEndpoint[2][0], bytes32("https://endpoint3.example.com"));

        _stopPrank();
    }
}