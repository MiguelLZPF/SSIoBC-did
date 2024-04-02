// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager } from "@src/interfaces/IDidManager.sol";
import { ServiceStorage, Service, SERVICE_MAX_LENGTH, SERVICE_NAMESPACE } from "@src/ServiceStorage.sol";

struct CreateExampleDidParams {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 random;
  bytes32 vmId;
}

struct DidInfo {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 id;
  bytes32 idHash;
  address creator;
}

enum PerformedAction {
  CREATEorUPDATE,
  REMOVE,
  UNDEFINED
}

contract ServiceStorageTest is Test {
  //* Constants
  // General
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  // Specific
  bytes32 private constant DEFAULT_DID_METHOD0 = bytes32("lzpf");
  bytes32 private constant DEFAULT_DID_METHOD1 = bytes32("main");
  bytes32 private constant DEFAULT_DID_METHOD2 = bytes32(0);
  bytes32 private constant DEFAULT_VM_ID = bytes32("vm-0");
  bytes32 private constant DEFAULT_SERVICE_ID = bytes32("linked-domain");
  bytes32[SERVICE_MAX_LENGTH] private DEFAULT_SERVICE_TYPE = [bytes32("LinkedDomains")];
  bytes32[SERVICE_MAX_LENGTH] private DEFAULT_SERVICE_ENDPOINT = [
    bytes32("https://bar.example.com")
  ];

  CreateExampleDidParams CREATE_EXAMPLE_DID_PARAMS =
    CreateExampleDidParams(
      bytes32("my-method0"),
      bytes32("my-method1"),
      bytes32("my-method2"),
      keccak256("randomString"),
      bytes32("verifMethod_01")
    );
  // Variables
  // -- users
  address admin = DEFAULT_SENDER;
  address payable[] users = [payable(address(10)), payable(address(11))];
  address user = users[0];
  address otherUser = users[1];
  // -- contracts
  IDidManager emptyDidManager;
  DidInfo firstDidInfo;
  IDidManager firstDidManager;

  /**
   * @dev Sets up the test environment by transferring some ether to users and deploying the DidManager contract.
   */
  function setUp() public {
    // Transfer some ether to users
    for (uint i = 0; i < users.length; i++) {
      vm.deal(users[i], DEFAULT_USER_BALANCE);
    }
    // Label users
    vm.label(admin, "admin");
    vm.label(user, "user");
    vm.label(otherUser, "otherUser");
    // Deploy initial state contracts
    emptyDidManager = _deployNewDidManager();
    vm.etch(address(101), address(emptyDidManager).code);
    firstDidManager = IDidManager(address(101));
    // -- first DID
    vm.startPrank(users[0]);
    (firstDidInfo, , , , , , ) = _createDid(
      firstDidManager,
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32("random"),
      bytes32(0)
    );
    vm.stopPrank();
  }

  //* TESTS
  function test_should_addNewService() public {
    //* 🗂️ Arrange ⬇
    IDidManager didManager = firstDidManager;
    DidInfo memory didData = firstDidInfo;
    vm.startPrank(users[0]);
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

  // * Internal functions
  function _deployNewDidManager() internal returns (IDidManager didManager) {
    (didManager, ) = new DidManagerScript().deploy(
      DeployCommand({ storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) }) }),
      false
    );
  }

  function _createDid(
    IDidManager didManager,
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random,
    bytes32 vmId
  )
    internal
    returns (
      DidInfo memory didInfo,
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmValidated_id,
      bytes32 DidCreated_id,
      bytes32 DidCreated_idHash,
      address DidCreated_creator
    )
  {
    // Event recording
    vm.recordLogs();
    //* Create DID call
    didManager.createDid(method0, method1, method2, random, vmId);
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    VmCreated_didIdHash = entries[0].topics[1];
    VmCreated_id = entries[0].topics[2];
    // VmValidated(bytes32 indexed id);
    VmValidated_id = entries[1].topics[1];
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    DidCreated_id = entries[2].topics[1];
    DidCreated_idHash = entries[2].topics[2];
    DidCreated_creator = address(uint160(uint256((entries[2].topics[3]))));
    // Return structured Data
    didInfo = DidInfo({
      method0: DEFAULT_DID_METHOD0,
      method1: DEFAULT_DID_METHOD1,
      method2: DEFAULT_DID_METHOD2,
      id: DidCreated_id,
      idHash: DidCreated_idHash,
      creator: DidCreated_creator
    });
  }

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
      ? PerformedAction.REMOVE
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
}
