// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, VerificationMethod, EXPIRATION } from "@src/interfaces/IDidManager.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";

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
        msg.sender,
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
      DidInfo memory didInfo,
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
    bytes32 expectedIdHash = keccak256(
      abi.encodePacked(DEFAULT_DID_METHOD0, DEFAULT_DID_METHOD1, DEFAULT_DID_METHOD2, id)
    );
    bytes32 expectedVmIdHash = keccak256(abi.encodePacked(expectedIdHash, VM_ID_CUSTOM));
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
    assertEq(VmCreated_didIdHash, expectedIdHash);
    assertEq(VmCreated_id, DEFAULT_VM_ID);
    // VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, DEFAULT_VM_ID);
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertEq(DidCreated_id, id);
    assertEq(DidCreated_idHash, expectedIdHash);
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
        msg.sender,
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
      DidInfo memory didInfo,
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
    bytes32 expectedIdHash = keccak256(
      abi.encodePacked(DID_METHOD_0_CUSTOM, DID_METHOD_1_CUSTOM, DID_METHOD_2_CUSTOM, id)
    );
    bytes32 expectedVmIdHash = keccak256(abi.encodePacked(expectedIdHash, VM_ID_CUSTOM));
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
    assertEq(VmCreated_didIdHash, expectedIdHash);
    assertEq(VmCreated_id, DEFAULT_VM_ID);
    // VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, DEFAULT_VM_ID);
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertEq(DidCreated_id, id);
    assertEq(DidCreated_idHash, expectedIdHash);
    assertEq(DidCreated_creator, user);
    assertEq(DidCreated_idHash, VmCreated_didIdHash);
    // end
    vm.stopPrank();
  }

  function test_should_updateSameController() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory defaultDid, , , , , , ) = _createDid(
      didManager,
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(uint256(uint160(msg.sender))),
      bytes32(0)
    );
    // TODO // Initial state check
    //* 🎬 Act ⬇
    // Update controller
    (
      bytes32 ControllerUpdated_fromDidHash,
      bytes32 ControllerUpdated_toDidHash
    ) = _updateController(
        defaultDid.method0,
        defaultDid.method1,
        defaultDid.method2,
        defaultDid.id,
        DEFAULT_VM_ID,
        defaultDid.id,
        defaultDid.id,
        DEFAULT_VM_ID,
        0
      );
    //* ☑️ Assert ⬇
    // Check Events
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, uint8 controllerPosition, bytes32 method0, bytes32 method1, bytes32 method2, bytes32 id, bytes32 vmId)
    assertGt(uint256(ControllerUpdated_fromDidHash), uint256(100));
    assertGt(uint256(ControllerUpdated_toDidHash), uint256(100));
    assertEq(ControllerUpdated_fromDidHash, defaultDid.idHash);
    assertEq(ControllerUpdated_toDidHash, defaultDid.idHash);
    vm.stopPrank();
    // TODO // Final state check
  }

  // * Internal functions

  function _updateController(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 fromId,
    bytes32 fromVmId,
    bytes32 toId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) internal returns (bytes32 ControllerUpdated_fromDidHash, bytes32 ControllerUpdated_toDidHash) {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.updateController(
      method0,
      method1,
      method2,
      fromId,
      fromVmId,
      toId,
      controllerId,
      controllerVmId,
      controllerPosition
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, uint8 controllerPosition, bytes32 method0, bytes32 method1, bytes32 method2, bytes32 id, bytes32 vmId)
    ControllerUpdated_fromDidHash = entries[0].topics[1];
    ControllerUpdated_toDidHash = entries[0].topics[2];
    // TODO: check entries[0].data
  }
}
