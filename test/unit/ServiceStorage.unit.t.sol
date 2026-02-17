// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import {
  IServiceStorage,
  Service,
  MAX_SERVICE_TYPE_LENGTH,
  MAX_SERVICE_ENDPOINT_LENGTH
} from "@src/interfaces/IServiceStorage.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";

/**
 * @title ServiceStorageUnitTest
 * @notice Unit tests for service storage functionality in DidManager
 * @dev Tests service creation, updates, deletion, and retrieval using optimized dynamic bytes
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
    assertEq(string(service.type_), "LinkedDomains");
    assertEq(string(service.serviceEndpoint), "https://bar.example.com");

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
    bytes memory newServiceType = "UpdatedServiceType";
    bytes memory newServiceEndpoint = "https://updated.example.com";

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
    Service memory service =
      didManager.getService(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.DEFAULT_SERVICE_ID, 0);

    assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
    assertEq(string(service.type_), "UpdatedServiceType");
    assertEq(string(service.serviceEndpoint), "https://updated.example.com");

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
    bytes memory service2Type = "SecondServiceType";
    bytes memory service2Endpoint = "https://service2.example.com";

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
    Service memory service1 =
      didManager.getService(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.DEFAULT_SERVICE_ID, 0);
    assertEq(service1.id, Fixtures.DEFAULT_SERVICE_ID);
    assertEq(string(service1.type_), "LinkedDomains");

    // Verify: Second service details
    Service memory service2 =
      didManager.getService(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.SERVICE_ID_TEST_1, 0);
    assertEq(service2.id, Fixtures.SERVICE_ID_TEST_1);
    assertEq(string(service2.type_), "SecondServiceType");

    _stopPrank();
  }

  function test_RevertWhen_UpdateService_WithEmptyServiceId() public {
    _startPrank(user1);

    // Setup: Create a DID first
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Test: Try to create service with empty ID
    vm.expectRevert(IServiceStorage.ServiceIdCannotBeZero.selector);
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
    vm.expectRevert(IServiceStorage.ServiceTypeCannotBeEmpty.selector);
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.emptyServiceType(), // Empty service type
      Fixtures.defaultServiceEndpoint()
    );

    _stopPrank();
  }

  function test_RevertWhen_UpdateService_WithEmptyServiceEndpoint() public {
    _startPrank(user1);

    // Setup: Create a DID first
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Test: Try to create service with empty endpoint
    vm.expectRevert(IServiceStorage.ServiceEndpointCannotBeEmpty.selector);
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.emptyServiceEndpoint() // Empty service endpoint
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

    // Test: Delete service by providing empty type and endpoint
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.emptyServiceType(),
      Fixtures.emptyServiceEndpoint()
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
    bytes memory service2Type = "SecondServiceType";
    bytes memory service2Endpoint = "https://service2.example.com";

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
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.emptyServiceType(),
      Fixtures.emptyServiceEndpoint()
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
      Fixtures.emptyServiceType(),
      Fixtures.emptyServiceEndpoint()
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
    assertEq(string(service.type_), "LinkedDomains");
    assertEq(string(service.serviceEndpoint), "https://bar.example.com");

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
    assertEq(string(service.type_), "LinkedDomains");
    assertEq(string(service.serviceEndpoint), "https://bar.example.com");

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
    assertEq(service.type_.length, 0);
    assertEq(service.serviceEndpoint.length, 0);

    _stopPrank();
  }

  function test_GetService_Should_ReturnEmptyService_When_NonExistentIdProvided() public {
    _startPrank(user1);

    // Setup: Create a DID (no services)
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Test: Get service with non-existent ID
    Service memory service =
      didManager.getService(didResult.didInfo.methods, didResult.didInfo.id, bytes32("non-existent-service"), 0);

    // Verify: Empty service returned
    assertEq(service.id, bytes32(0));
    assertEq(service.type_.length, 0);
    assertEq(service.serviceEndpoint.length, 0);

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
    bytes memory service2Type = "SecondServiceType";
    bytes memory service2Endpoint = "https://service2.example.com";

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
    uint256 length = didManager.getServiceListLength(Fixtures.CUSTOM_DID_METHODS, bytes32("non-existent-did"));

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
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.emptyServiceType(),
      Fixtures.emptyServiceEndpoint()
    );

    // Verify: Service list length decreased
    uint256 afterDeletion = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(afterDeletion, 0);

    _stopPrank();
  }

  // =========================================================================
  // COMPLEX SCENARIOS TESTS
  // =========================================================================

  function test_UpdateService_Should_HandleMultipleTypesAndEndpoints_When_PackedWithDelimiter() public {
    _startPrank(user1);

    // Setup: Create a DID first
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Test: Create service with multiple types and endpoints using delimiter
    bytes memory multipleTypes = "ServiceType1\x00ServiceType2";
    bytes memory multipleEndpoints =
      "https://endpoint1.example.com\x00https://endpoint2.example.com\x00https://endpoint3.example.com";

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
    Service memory service =
      didManager.getService(didResult.didInfo.methods, didResult.didInfo.id, Fixtures.DEFAULT_SERVICE_ID, 0);

    assertEq(service.id, Fixtures.DEFAULT_SERVICE_ID);
    // The raw bytes contain the packed format with delimiters
    assertEq(string(service.type_), "ServiceType1\x00ServiceType2");
    assertEq(
      string(service.serviceEndpoint),
      "https://endpoint1.example.com\x00https://endpoint2.example.com\x00https://endpoint3.example.com"
    );

    _stopPrank();
  }

  // =========================================================================
  // SIZE LIMIT TESTS
  // =========================================================================

  function test_RevertWhen_UpdateService_WithTypeTooLarge() public {
    _startPrank(user1);

    // Setup: Create a DID first
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create type that exceeds MAX_SERVICE_TYPE_LENGTH (500)
    bytes memory oversizedType = new bytes(MAX_SERVICE_TYPE_LENGTH + 1);
    for (uint256 i = 0; i < oversizedType.length; i++) {
      oversizedType[i] = "A";
    }

    // Test: Try to create service with oversized type
    vm.expectRevert(IServiceStorage.ServiceTypeTooLarge.selector);
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      oversizedType,
      Fixtures.defaultServiceEndpoint()
    );

    _stopPrank();
  }

  function test_RevertWhen_UpdateService_WithEndpointTooLarge() public {
    _startPrank(user1);

    // Setup: Create a DID first
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create endpoint that exceeds MAX_SERVICE_ENDPOINT_LENGTH (2000)
    bytes memory oversizedEndpoint = new bytes(MAX_SERVICE_ENDPOINT_LENGTH + 1);
    for (uint256 i = 0; i < oversizedEndpoint.length; i++) {
      oversizedEndpoint[i] = "A";
    }

    // Test: Try to create service with oversized endpoint
    vm.expectRevert(IServiceStorage.ServiceEndpointTooLarge.selector);
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      oversizedEndpoint
    );

    _stopPrank();
  }

  function test_UpdateService_Should_AcceptMaxSizeTypeAndEndpoint() public {
    _startPrank(user1);

    // Setup: Create a DID first
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create type at exactly MAX_SERVICE_TYPE_LENGTH
    bytes memory maxType = new bytes(MAX_SERVICE_TYPE_LENGTH);
    for (uint256 i = 0; i < maxType.length; i++) {
      maxType[i] = "T";
    }

    // Create endpoint at exactly MAX_SERVICE_ENDPOINT_LENGTH
    bytes memory maxEndpoint = new bytes(MAX_SERVICE_ENDPOINT_LENGTH);
    for (uint256 i = 0; i < maxEndpoint.length; i++) {
      maxEndpoint[i] = "E";
    }

    // Test: Create service with max size type and endpoint - should succeed
    didManager.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      maxType,
      maxEndpoint
    );

    // Verify: Service was created
    uint256 serviceLength = didManager.getServiceListLength(didResult.didInfo.methods, didResult.didInfo.id);
    assertEq(serviceLength, 1);

    _stopPrank();
  }
}
