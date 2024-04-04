// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager } from "@src/interfaces/IDidManager.sol";
import { ServiceStorage, Service, SERVICE_MAX_LENGTH, SERVICE_NAMESPACE } from "@src/ServiceStorage.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";

enum PerformedAction {
  CREATEorUPDATE,
  DELETE,
  UNDEFINED
}

contract ServiceStorageTest is SharedTest {
  //* Constants
  // General
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  uint256 private constant INIT_CONTRACTS = 6;
  // Specific
  bytes32 private constant DEFAULT_SERVICE_ID = bytes32("linked-domain");
  bytes32[SERVICE_MAX_LENGTH] private DEFAULT_SERVICE_TYPE = [bytes32("LinkedDomains")];
  bytes32[SERVICE_MAX_LENGTH] private DEFAULT_SERVICE_ENDPOINT = [
    bytes32("https://bar.example.com")
  ];
  bytes32[SERVICE_MAX_LENGTH] private UPDATE_SERVICE_TYPE = [
    DEFAULT_SERVICE_TYPE[0],
    bytes32("NewType")
  ];
  bytes32[SERVICE_MAX_LENGTH] private UPDATE_SERVICE_ENDPOINT = [
    DEFAULT_SERVICE_ENDPOINT[0],
    bytes32("https://new.endpoint.com")
  ];
  bytes32[SERVICE_MAX_LENGTH] private EMPTY_SERVICE_TYPE = [bytes32(0)];
  bytes32[SERVICE_MAX_LENGTH] private EMPTY_SERVICE_ENDPOINT = [bytes32(0)];

  // Variables
  // -- users
  address admin = DEFAULT_SENDER;
  address user = payable(address(10));
  address otherUser = payable(address(11));
  // -- contracts
  uint256 lastDidManagerUsed;
  IDidManager[] initDidManagers;
  DidInfo firstDidInfo;

  /**
   * @dev Sets up the test environment by transferring some ether to users and deploying the DidManager contract.
   */
  function setUp() public {
    // // Transfer some ether to users
    // for (uint i = 0; i < users.length; i++) {
    //   vm.deal(users[i], DEFAULT_USER_BALANCE);
    // }
    // Label users
    vm.label(admin, "admin");
    vm.label(user, "user");
    vm.label(otherUser, "otherUser");
    // Deploy initial state contracts
    // -- initialize N DidManagers
    for (uint256 i = 0; i < INIT_CONTRACTS; i++) {
      IDidManager didManager = _deployNewDidManager();
      initDidManagers.push(didManager);
      vm.label(address(didManager), string(abi.encodePacked("initDidManager_", i)));
      startHoax(user, DEFAULT_USER_BALANCE);
      (firstDidInfo, , , , , , ) = _createDid(
        didManager,
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32("random"),
        bytes32(0)
      );
      vm.stopPrank();
    }
  }

  //* TESTS
  function test_should_addNewService() public {
    //* 🗂️ Arrange ⬇
    IDidManager didManager = _getNextInitDidManager();
    DidInfo memory didData = firstDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 0);
    Service memory service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0], bytes32(0));
    assertEq(service.serviceEndpoint[0], bytes32(0));
    //* 🎬 Act ⬇
    // Add new service
    (
      PerformedAction performedAction,
      bytes32 ServiceUpdated_didIdHash,
      bytes32 ServiceUpdated_id,
      bytes32 ServiceUpdated_serviceIdHash,
      bytes32 ServiceUpdated_positionHash
    ) = _updateService(
        didManager,
        didData.method0,
        didData.method1,
        didData.method2,
        didData.id,
        DEFAULT_VM_ID,
        didData.id,
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
      didData.id
    );
    bytes32 serviceDidHash = keccak256(abi.encodePacked(didData.idHash, SERVICE_NAMESPACE));
    bytes32 expectedServiceIdHash = keccak256(abi.encodePacked(serviceDidHash, DEFAULT_SERVICE_ID));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(serviceDidHash, uint8(0)));
    // Check final state
    assertEq(length, 1);
    // -- final "first service"
    service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(0)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0], DEFAULT_SERVICE_TYPE[0]);
    assertEq(service.serviceEndpoint[0], DEFAULT_SERVICE_ENDPOINT[0]);
    // -- final service by ID
    service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0], DEFAULT_SERVICE_TYPE[0]);
    assertEq(service.serviceEndpoint[0], DEFAULT_SERVICE_ENDPOINT[0]);
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
    assertEq(ServiceUpdated_didIdHash, didData.idHash);
    assertEq(ServiceUpdated_id, DEFAULT_SERVICE_ID);
    assertEq(ServiceUpdated_serviceIdHash, expectedServiceIdHash);
    assertEq(ServiceUpdated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_should_updateService() public {
    //* 🗂️ Arrange ⬇
    IDidManager didManager = _getNextInitDidManager();
    DidInfo memory didData = firstDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new service
    (
      PerformedAction performedAction,
      bytes32 ServiceUpdated_didIdHash,
      bytes32 ServiceUpdated_id,
      bytes32 ServiceUpdated_serviceIdHash,
      bytes32 ServiceUpdated_positionHash
    ) = _updateService(
        didManager,
        didData.method0,
        didData.method1,
        didData.method2,
        didData.id,
        DEFAULT_VM_ID,
        didData.id,
        DEFAULT_SERVICE_ID,
        DEFAULT_SERVICE_TYPE,
        DEFAULT_SERVICE_ENDPOINT
      );
    // Check previous state
    assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Update service
    (
      performedAction,
      ServiceUpdated_didIdHash,
      ServiceUpdated_id,
      ServiceUpdated_serviceIdHash,
      ServiceUpdated_positionHash
    ) = _updateService(
      didManager,
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      DEFAULT_SERVICE_ID,
      UPDATE_SERVICE_TYPE,
      UPDATE_SERVICE_ENDPOINT
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
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(serviceDidHash, uint8(0)));
    // Check final state
    assertEq(length, 1);
    // -- final "first service"
    Service memory service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(0)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0], UPDATE_SERVICE_TYPE[0]);
    assertEq(service.type_[1], UPDATE_SERVICE_TYPE[1]);
    assertEq(service.type_[2], bytes32(0));
    assertEq(service.serviceEndpoint[0], UPDATE_SERVICE_ENDPOINT[0]);
    assertEq(service.serviceEndpoint[1], UPDATE_SERVICE_ENDPOINT[1]);
    assertEq(service.serviceEndpoint[2], bytes32(0));
    // -- final service by ID
    service = didManager.getService(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_SERVICE_ID,
      uint8(0)
    );
    assertEq(service.id, DEFAULT_SERVICE_ID);
    assertEq(service.type_[0], UPDATE_SERVICE_TYPE[0]);
    assertEq(service.type_[1], UPDATE_SERVICE_TYPE[1]);
    assertEq(service.type_[2], bytes32(0));
    assertEq(service.serviceEndpoint[0], UPDATE_SERVICE_ENDPOINT[0]);
    assertEq(service.serviceEndpoint[1], UPDATE_SERVICE_ENDPOINT[1]);
    assertEq(service.serviceEndpoint[2], bytes32(0));
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
    assertEq(ServiceUpdated_didIdHash, didData.idHash);
    assertEq(ServiceUpdated_id, DEFAULT_SERVICE_ID);
    assertEq(ServiceUpdated_serviceIdHash, expectedServiceIdHash);
    assertEq(ServiceUpdated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_should_removeService() public {
    //* 🗂️ Arrange ⬇
    IDidManager didManager = _getNextInitDidManager();
    DidInfo memory didData = firstDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new service
    (
      PerformedAction performedAction,
      bytes32 ServiceUpdated_didIdHash,
      bytes32 ServiceUpdated_id,
      bytes32 ServiceUpdated_serviceIdHash,
      bytes32 ServiceUpdated_positionHash
    ) = _updateService(
        didManager,
        didData.method0,
        didData.method1,
        didData.method2,
        didData.id,
        DEFAULT_VM_ID,
        didData.id,
        DEFAULT_SERVICE_ID,
        DEFAULT_SERVICE_TYPE,
        DEFAULT_SERVICE_ENDPOINT
      );
    // Check previous state
    assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
    uint256 length = didManager.getServiceListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Delete service
    (
      performedAction,
      ServiceUpdated_didIdHash,
      ServiceUpdated_id,
      ServiceUpdated_serviceIdHash,
      ServiceUpdated_positionHash
    ) = _updateService(
      didManager,
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      DEFAULT_SERVICE_ID,
      EMPTY_SERVICE_TYPE,
      EMPTY_SERVICE_ENDPOINT
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
      uint8(0)
    );
    assertEq(service.id, bytes32(0));
    assertEq(service.type_[0], bytes32(0));
    assertEq(service.serviceEndpoint[0], bytes32(0));
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
    assertEq(service.type_[0], bytes32(0));
    assertEq(service.serviceEndpoint[0], bytes32(0));
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(performedAction == PerformedAction.DELETE);
    assertEq(ServiceUpdated_didIdHash, didData.idHash);
    assertEq(ServiceUpdated_id, DEFAULT_SERVICE_ID);
    assertEq(ServiceUpdated_serviceIdHash, expectedServiceIdHash);
    assertEq(ServiceUpdated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  // * Internal functions

  /**
   * @dev Updates a service.
   */
  function _updateService(
    IDidManager didManager,
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes32[SERVICE_MAX_LENGTH] memory type_,
    bytes32[SERVICE_MAX_LENGTH] memory serviceEndpoint
  )
    internal
    returns (
      PerformedAction performedAction,
      bytes32 ServiceUpdated_didIdHash,
      bytes32 ServiceUpdated_id,
      bytes32 ServiceUpdated_serviceIdHash,
      bytes32 ServiceUpdated_positionHash
    )
  {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.updateService(
      method0,
      method1,
      method2,
      senderId,
      senderVmId,
      targetId,
      serviceId,
      type_,
      serviceEndpoint
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Induce performed action
    performedAction = entries.length == 1 ? PerformedAction.CREATEorUPDATE : entries.length == 2
      ? PerformedAction.DELETE
      : PerformedAction.UNDEFINED;
    // Get the event values
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    ServiceUpdated_didIdHash = entries[0].topics[1];
    ServiceUpdated_id = entries[0].topics[2];
    ServiceUpdated_serviceIdHash = entries[0].topics[3];
    ServiceUpdated_positionHash = bytes32(entries[0].data);
  }

  /**
   * @dev Retrieves the next initialized DidManager contract.
   * @return didManager The next initialized DidManager contract.
   */
  function _getNextInitDidManager() internal returns (IDidManager didManager) {
    didManager = initDidManagers[lastDidManagerUsed];
    lastDidManagerUsed++;
    return didManager;
  }
}
