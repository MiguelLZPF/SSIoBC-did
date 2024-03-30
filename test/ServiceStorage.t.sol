// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, SERVICE_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
// import { IVMStorage } from "@src/interfaces/IVMStorage.sol";

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
  CreateExampleDidParams CREATE_EXAMPLE_DID_PARAMS =
    CreateExampleDidParams(
      bytes32("my-method0"),
      bytes32("my-method1"),
      bytes32("my-method2"),
      keccak256("randomString"),
      bytes32("verifMethod_01")
    );
  // Variables
  // IDidManager public didManager;
  address admin = DEFAULT_SENDER;
  address payable[] users = [payable(address(20)), payable(address(21)), payable(address(22))];

  /**
   * @dev Sets up the test environment by transferring some ether to users and deploying the DidManager contract.
   */
  function setUp() public {
    // Transfer some ether to users
    for (uint i = 0; i < users.length; i++) {
      vm.deal(users[i], DEFAULT_USER_BALANCE);
    }
  }

  //* TESTS
  function test_should_addNewService() public {
    //* 🗂️ Arrange ⬇
    IDidManager didManager = _deployNewDidManager();
    vm.startPrank(users[0]);
    // Create DID
    (DidInfo memory data, , , , , , ) = _createDid(
      didManager,
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(uint256(uint160(msg.sender))),
      bytes32(0)
    );
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
        data.method0,
        data.method1,
        data.method2,
        data.id,
        DEFAULT_VM_ID,
        data.id,
        DEFAULT_SERVICE_ID,
        [
          bytes32("LinkedDomains"),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0)
        ],
        [
          bytes32("https://bar.example.com"),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0),
          bytes32(0)
        ]
      );
    //* ☑️ Assert ⬇
    // Check Events
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
    // Final state check
    // end
    vm.stopPrank();
  }

  // * Internal functions

  function _deployNewDidManager() internal returns (IDidManager didManager) {
    (didManager, ) = new DidManagerScript().deploy(
      DeployCommand({ storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) }) })
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
    ServiceUpdated_positionHash = entries[0].data[0];
  }
}
