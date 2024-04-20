// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, VerificationMethod, Controller, EXPIRATION, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";

struct UpdateControllerCommandTest {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 senderId;
  bytes32 senderVmId;
  bytes32 targetId;
  bytes32 controllerId;
  bytes32 controllerVmId;
  uint8 controllerPosition;
}

struct UpdateControllerResponseTest {
  bytes32 ControllerUpdated_senderDidHash;
  bytes32 ControllerUpdated_targetDidHash;
  uint8 ControllerUpdated_controllerPosition;
  bytes32 ControllerUpdated_vmId;
}

contract DidManagerTest is SharedTest {
  //* Constants
  // General
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  // Specific
  bytes32 private constant RANDOM_CREATE_DEFAULT = bytes32("This is a random value");
  bytes32 private constant RANDOM_CREATE_CUSTOM = bytes32("This is another random value");
  bytes32 private constant DID_METHOD_0_CUSTOM = bytes32("method0_custom");
  bytes32 private constant DID_METHOD_1_CUSTOM = bytes32("method1_custom");
  bytes32 private constant DID_METHOD_2_CUSTOM = bytes32("method2_custom");
  bytes32 private constant VM_ID_CUSTOM = bytes32("vm_custom");
  // Variables
  // -- users
  address admin = DEFAULT_SENDER;
  address user = payable(address(10));
  address otherUser = payable(address(11));
  // -- contracts
  uint256 lastDidManagerUsed;
  IDidManager didManager;

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
    // Label contracts
    vm.label(address(didManager), "blankDidManager");
  }

  //* TESTS
  // CREATE DID
  function test_should_createDid_withDefaultParams() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check initial state
    // ! Not possible | really difficult in real newtorks
    bytes32 id = keccak256(
      abi.encodePacked(
        DEFAULT_DID_METHOD0,
        DEFAULT_DID_METHOD1,
        DEFAULT_DID_METHOD2,
        RANDOM_CREATE_DEFAULT,
        user,
        block.timestamp
      )
    );
    uint256 exp = didManager.getExpiration(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      id
    );
    assertEq(length, 0);
    //* 🎬 Act ⬇
    // Create DID
    (
      ,
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmValidated_id,
      bytes32 DidCreated_id,
      bytes32 DidCreated_idHash,
      address DidCreated_creator
    ) = _createDid(
        didManager,
        EMPTY_DID_METHOD,
        EMPTY_DID_METHOD,
        EMPTY_DID_METHOD,
        RANDOM_CREATE_DEFAULT,
        EMPTY_VM_ID
      );
    //* ☑️ Assert ⬇
    // Check final state
    exp = didManager.getExpiration(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, block.timestamp + EXPIRATION);
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      id
    );
    assertEq(length, 1);
    // Check Events
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    assertEq(
      VmCreated_didIdHash,
      _calculateDidHash(DEFAULT_DID_METHOD0, DEFAULT_DID_METHOD1, DEFAULT_DID_METHOD2, id)
    );
    assertEq(VmCreated_id, DEFAULT_VM_ID);
    // VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, DEFAULT_VM_ID);
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertEq(DidCreated_id, id);
    assertEq(
      DidCreated_idHash,
      _calculateDidHash(DEFAULT_DID_METHOD0, DEFAULT_DID_METHOD1, DEFAULT_DID_METHOD2, id)
    );
    assertEq(DidCreated_creator, user);
    assertEq(DidCreated_idHash, VmCreated_didIdHash);
    // end
    vm.stopPrank();
  }

  function test_should_createDid_withCustomParams() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check initial state
    // ! Not possible | really difficult in real newtorks
    bytes32 id = keccak256(
      abi.encodePacked(
        DID_METHOD_0_CUSTOM,
        DID_METHOD_1_CUSTOM,
        DID_METHOD_2_CUSTOM,
        RANDOM_CREATE_CUSTOM,
        user,
        block.timestamp
      )
    );
    uint256 exp = didManager.getExpiration(
      DID_METHOD_0_CUSTOM,
      DID_METHOD_1_CUSTOM,
      DID_METHOD_2_CUSTOM,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(
      DID_METHOD_0_CUSTOM,
      DID_METHOD_1_CUSTOM,
      DID_METHOD_2_CUSTOM,
      id
    );
    assertEq(length, 0);
    //* 🎬 Act ⬇
    // Create DID
    (
      ,
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmValidated_id,
      bytes32 DidCreated_id,
      bytes32 DidCreated_idHash,
      address DidCreated_creator
    ) = _createDid(
        didManager,
        DID_METHOD_0_CUSTOM,
        DID_METHOD_1_CUSTOM,
        DID_METHOD_2_CUSTOM,
        RANDOM_CREATE_CUSTOM,
        VM_ID_CUSTOM
      );
    //* ☑️ Assert ⬇
    // Check final state
    exp = didManager.getExpiration(
      DID_METHOD_0_CUSTOM,
      DID_METHOD_1_CUSTOM,
      DID_METHOD_2_CUSTOM,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, block.timestamp + EXPIRATION);
    length = didManager.getVmListLength(
      DID_METHOD_0_CUSTOM,
      DID_METHOD_1_CUSTOM,
      DID_METHOD_2_CUSTOM,
      id
    );
    assertEq(length, 1);
    // Check Events
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    assertEq(
      VmCreated_didIdHash,
      _calculateDidHash(DID_METHOD_0_CUSTOM, DID_METHOD_1_CUSTOM, DID_METHOD_2_CUSTOM, id)
    );
    assertEq(VmCreated_id, VM_ID_CUSTOM);
    // VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, VM_ID_CUSTOM);
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertEq(DidCreated_id, id);
    assertEq(
      DidCreated_idHash,
      _calculateDidHash(DID_METHOD_0_CUSTOM, DID_METHOD_1_CUSTOM, DID_METHOD_2_CUSTOM, id)
    );
    assertEq(DidCreated_creator, user);
    assertEq(DidCreated_idHash, VmCreated_didIdHash);
    // end
    vm.stopPrank();
  }

  // UPDATE CONTROLLER
  function test_should_updateSameController() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory defaultDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      defaultDid.method0,
      defaultDid.method1,
      defaultDid.method2,
      defaultDid.id
    );
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    // Update controller
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      method0: defaultDid.method0,
      method1: defaultDid.method1,
      method2: defaultDid.method2,
      senderId: defaultDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: defaultDid.id,
      controllerId: defaultDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    UpdateControllerResponseTest memory res = _updateController(command);
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(
      defaultDid.method0,
      defaultDid.method1,
      defaultDid.method2,
      defaultDid.id
    );
    assertEq(controllers[0].id, defaultDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    // Check Events
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, uint8 controllerPosition, bytes32 method0, bytes32 method1, bytes32 method2, bytes32 id, bytes32 vmId)
    assertEq(
      res.ControllerUpdated_senderDidHash,
      _calculateDidHash(defaultDid.method0, defaultDid.method1, defaultDid.method2, defaultDid.id)
    );
    assertEq(
      res.ControllerUpdated_targetDidHash,
      _calculateDidHash(defaultDid.method0, defaultDid.method1, defaultDid.method2, defaultDid.id)
    );
    assertEq(res.ControllerUpdated_senderDidHash, defaultDid.idHash);
    assertEq(res.ControllerUpdated_targetDidHash, defaultDid.idHash);
    // end
    vm.stopPrank();
  }

  // * Internal functions

  function _updateController(
    UpdateControllerCommandTest memory command
  ) internal returns (UpdateControllerResponseTest memory response) {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.updateController(
      command.method0,
      command.method1,
      command.method2,
      command.senderId,
      command.senderVmId,
      command.targetId,
      command.controllerId,
      command.controllerVmId,
      command.controllerPosition
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // event ControllerUpdated(
    //   bytes32 indexed senderDidHash,
    //   bytes32 indexed targetDidHash,
    //   uint8 controllerPosition,
    //   bytes32 vmId
    // );
    response.ControllerUpdated_senderDidHash = entries[0].topics[1];
    response.ControllerUpdated_targetDidHash = entries[0].topics[2];
    (response.ControllerUpdated_controllerPosition, response.ControllerUpdated_vmId) = abi.decode(
      entries[0].data,
      (uint8, bytes32)
    );
  }
}
