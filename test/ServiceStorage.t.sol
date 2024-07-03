// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager } from "@src/interfaces/IDidManager.sol";
import { DidManager } from "@src/DidManager.sol";
import { ServiceStorage, Service, SERVICE_MAX_LENGTH_LIST, SERVICE_MAX_LENGTH, SERVICE_NAMESPACE } from "@src/ServiceStorage.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";

enum PerformedAction {
  CREATEorUPDATE,
  DELETE,
  UNDEFINED
}

struct ServiceUpdateCommandTest {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 senderId;
  bytes32 senderVmId;
  bytes32 targetId;
  bytes32 serviceId;
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] type_;
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] serviceEndpoint;
}

struct ServiceUpdateResultTest {
  PerformedAction performedAction;
  bytes32 ServiceUpdated_didIdHash;
  bytes32 ServiceUpdated_id;
  bytes32 ServiceUpdated_serviceIdHash;
  bytes32 ServiceUpdated_positionHash;
}

contract ServiceStorageTest is SharedTest {
  //* Constants
  // Specific
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] private UPDATE_SERVICE_TYPE = [
    [DEFAULT_SERVICE_TYPE[0][0]],
    [bytes32("NewType")]
  ];
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] private UPDATE_SERVICE_ENDPOINT = [
    [DEFAULT_SERVICE_ENDPOINT[0][0]],
    [bytes32("https://new.endpoint.com")]
  ];
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] private EMPTY_SERVICE_TYPE = [[bytes32(0)]];
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] private EMPTY_SERVICE_ENDPOINT = [
    [bytes32(0)]
  ];

  // Variables
  // -- users
  address admin = DEFAULT_SENDER;
  address user = payable(address(10));
  address otherUser = payable(address(11));
  // -- contracts
  uint256 lastDidManagerUsed;
  DidInfo userDidInfo;
  DidInfo otherUserDidInfo;

  /**
   * @dev Sets up the test environment by transferring some ether to users and deploying the DidManager contract.
   */
  function setUp() public {
    // Label users
    vm.label(admin, "admin");
    vm.label(user, "user");
    vm.label(otherUser, "otherUser");
    // Deploy initial state contracts
    didManager = _deployNewDidManager();
    vm.label(address(didManager), "initDidManager");
    // Create a DID for user
    startHoax(user, DEFAULT_USER_BALANCE);
    (userDidInfo, , , , , , ) = _createDid(
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32("random"),
      bytes32(0)
    );
    vm.stopPrank();
    // Create a DID for other user
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    (otherUserDidInfo, , , , , , ) = _createDid(
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32("random"),
      bytes32(0)
    );
    vm.stopPrank();
  }

  //* TESTS
  // ADD SERVICE
  function test_should_addNewService() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    assertEq(length, 0);
    Service memory service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    //* 🎬 Act ⬇
    // Add new service
    ServiceUpdateResultTest memory result = _updateService(
      ServiceUpdateCommandTest({
        method0: userDidInfo.method0,
        method1: userDidInfo.method1,
        method2: userDidInfo.method2,
        senderId: userDidInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: userDidInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    bytes32 serviceDidHash = keccak256(abi.encodePacked(userDidInfo.idHash, SERVICE_NAMESPACE));
    bytes32 expectedServiceIdHash = keccak256(abi.encodePacked(serviceDidHash, DEFAULT_SERVICE_ID));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(serviceDidHash, uint8(1)));
    // Check final state
    assertEq(length, 1);
    // -- final "first service"
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    // TODO: Check all fields. Maybe a checkService function?
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0][0], DEFAULT_SERVICE_TYPE[0][0]);
    assertEq(service.serviceEndpoint[0][0], DEFAULT_SERVICE_ENDPOINT[0][0]);
    // -- final service by ID
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0][0], DEFAULT_SERVICE_TYPE[0][0]);
    assertEq(service.serviceEndpoint[0][0], DEFAULT_SERVICE_ENDPOINT[0][0]);
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(result.performedAction == PerformedAction.CREATEorUPDATE);
    assertEq(result.ServiceUpdated_didIdHash, userDidInfo.idHash);
    assertEq(result.ServiceUpdated_id, DEFAULT_SERVICE_ID);
    assertEq(result.ServiceUpdated_serviceIdHash, expectedServiceIdHash);
    assertEq(result.ServiceUpdated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  // UPDATE SERVICE
  function test_should_updateService() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new service
    ServiceUpdateResultTest memory result = _updateService(
      ServiceUpdateCommandTest({
        method0: userDidInfo.method0,
        method1: userDidInfo.method1,
        method2: userDidInfo.method2,
        senderId: userDidInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: userDidInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    // Check previous state
    assertTrue(result.performedAction == PerformedAction.CREATEorUPDATE);
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Update service
    result = _updateService(
      ServiceUpdateCommandTest({
        method0: userDidInfo.method0,
        method1: userDidInfo.method1,
        method2: userDidInfo.method2,
        senderId: userDidInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: userDidInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: UPDATE_SERVICE_TYPE,
        serviceEndpoint: UPDATE_SERVICE_ENDPOINT
      })
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    bytes32 serviceDidHash = keccak256(abi.encodePacked(userDidInfo.idHash, SERVICE_NAMESPACE));
    bytes32 expectedServiceIdHash = keccak256(abi.encodePacked(serviceDidHash, DEFAULT_SERVICE_ID));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(serviceDidHash, uint8(1)));
    // Check final state
    assertEq(length, 1);
    // -- final "first service"
    Service memory service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0][0], UPDATE_SERVICE_TYPE[0][0]);
    assertEq(service.type_[1][0], UPDATE_SERVICE_TYPE[1][0]);
    assertEq(service.type_[2][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], UPDATE_SERVICE_ENDPOINT[0][0]);
    assertEq(service.serviceEndpoint[1][0], UPDATE_SERVICE_ENDPOINT[1][0]);
    assertEq(service.serviceEndpoint[2][0], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0][0], UPDATE_SERVICE_TYPE[0][0]);
    assertEq(service.type_[1][0], UPDATE_SERVICE_TYPE[1][0]);
    assertEq(service.type_[2][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], UPDATE_SERVICE_ENDPOINT[0][0]);
    assertEq(service.serviceEndpoint[1][0], UPDATE_SERVICE_ENDPOINT[1][0]);
    assertEq(service.serviceEndpoint[2][0], bytes32(0));
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(result.performedAction == PerformedAction.CREATEorUPDATE);
    assertEq(result.ServiceUpdated_didIdHash, userDidInfo.idHash);
    assertEq(result.ServiceUpdated_id, DEFAULT_SERVICE_ID);
    assertEq(result.ServiceUpdated_serviceIdHash, expectedServiceIdHash);
    assertEq(result.ServiceUpdated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_updateService_notInControl() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didUserData = userDidInfo;
    DidInfo memory didOtherData = otherUserDidInfo;
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didUserData.id
    );
    assertEq(length, 0);
    Service memory service = didManager.getService(
      didUserData.method0,
      didUserData.method1,
      didUserData.method2,
      didUserData.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    //* 🎬 Act ⬇
    vm.expectRevert("Not a controller for target");
    // Add new service from other user
    didManager.updateService(
      didUserData.method0,
      didUserData.method1,
      didUserData.method2,
      didOtherData.id,
      DEFAULT_VM_ID,
      didUserData.id,
      DEFAULT_SERVICE_ID,
      DEFAULT_SERVICE_TYPE,
      DEFAULT_SERVICE_ENDPOINT
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didUserData.id
    );
    // Check final state
    assertEq(length, 0);
    // -- final "first service"
    service = didManager.getService(
      didUserData.method0,
      didUserData.method1,
      didUserData.method2,
      didUserData.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      didUserData.method0,
      didUserData.method1,
      didUserData.method2,
      didUserData.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // end
    vm.stopPrank();
  }

  // function test_shouldNot_updateService_emptyDidHash() public //! Not possible to test

  function test_shouldNot_updateService_emptyId() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    assertEq(length, 0);
    Service memory service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    //* 🎬 Act ⬇
    vm.expectRevert("ID cannot be 0");
    // Add new service from other user
    didManager.updateService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_VM_ID,
      userDidInfo.id,
      bytes32(0), //! <---- empty ID
      DEFAULT_SERVICE_TYPE,
      DEFAULT_SERVICE_ENDPOINT
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    // Check final state
    assertEq(length, 0);
    // -- final "first service"
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // end
    vm.stopPrank();
  }

  function test_shouldNot_updateService_emptyType() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    assertEq(length, 0);
    Service memory service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    //* 🎬 Act ⬇
    vm.expectRevert("Type cannot be 0");
    // Add new service from other user
    didManager.updateService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_VM_ID,
      userDidInfo.id,
      DEFAULT_SERVICE_ID,
      EMPTY_SERVICE_TYPE, //! <---- empty type
      DEFAULT_SERVICE_ENDPOINT
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    // Check final state
    assertEq(length, 0);
    // -- final "first service"
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // end
    vm.stopPrank();
  }

  function test_shouldNot_updateService_emptyEndpoint() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    assertEq(length, 0);
    Service memory service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    //* 🎬 Act ⬇
    vm.expectRevert("Endpoint cannot be 0");
    // Add new service from other user
    didManager.updateService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_VM_ID,
      userDidInfo.id,
      DEFAULT_SERVICE_ID,
      DEFAULT_SERVICE_TYPE,
      EMPTY_SERVICE_ENDPOINT //! <---- empty endpoint
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      userDidInfo.id
    );
    // Check final state
    assertEq(length, 0);
    // -- final "first service"
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      userDidInfo.method0,
      userDidInfo.method1,
      userDidInfo.method2,
      userDidInfo.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // end
    vm.stopPrank();
  }

  // REMOVE SERVICE
  function test_should_removeService() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new service
    ServiceUpdateResultTest memory result = _updateService(
      ServiceUpdateCommandTest({
        method0: didData.method0,
        method1: didData.method1,
        method2: didData.method2,
        senderId: didData.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didData.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    // Check previous state
    assertTrue(result.performedAction == PerformedAction.CREATEorUPDATE);
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Delete service
    result = _updateService(
      ServiceUpdateCommandTest({
        method0: didData.method0,
        method1: didData.method1,
        method2: didData.method2,
        senderId: didData.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didData.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: EMPTY_SERVICE_TYPE,
        serviceEndpoint: EMPTY_SERVICE_ENDPOINT
      })
    );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    bytes32 serviceDidHash = keccak256(abi.encodePacked(didData.idHash, SERVICE_NAMESPACE));
    bytes32 expectedServiceIdHash = keccak256(abi.encodePacked(serviceDidHash, DEFAULT_SERVICE_ID));
    bytes32 expectedPositionHash = 0;
    // Check final state
    assertEq(length, 0);
    // -- final "first service"
    Service memory service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(1)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0][0], bytes32(0));
    assertEq(service.serviceEndpoint[0][0], bytes32(0));
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(result.performedAction == PerformedAction.DELETE);
    assertEq(result.ServiceUpdated_didIdHash, didData.idHash);
    assertEq(result.ServiceUpdated_id, DEFAULT_SERVICE_ID);
    assertEq(result.ServiceUpdated_serviceIdHash, expectedServiceIdHash);
    assertEq(result.ServiceUpdated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  // * Internal functions

  /**
   * @dev Updates a service.
   */
  function _updateService(
    ServiceUpdateCommandTest memory command
  ) internal returns (ServiceUpdateResultTest memory result) {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.updateService(
      command.method0,
      command.method1,
      command.method2,
      command.senderId,
      command.senderVmId,
      command.targetId,
      command.serviceId,
      command.type_,
      command.serviceEndpoint
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Induce performed action
    result.performedAction = entries.length == 1
      ? PerformedAction.CREATEorUPDATE
      : entries.length == 2
      ? PerformedAction.DELETE
      : PerformedAction.UNDEFINED;
    // Get the event values
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    result.ServiceUpdated_didIdHash = entries[0].topics[1];
    result.ServiceUpdated_id = entries[0].topics[2];
    result.ServiceUpdated_serviceIdHash = entries[0].topics[3];
    result.ServiceUpdated_positionHash = bytes32(entries[0].data);
  }
}
