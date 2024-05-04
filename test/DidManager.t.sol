// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";
import { IDidManager, VerificationMethod, Controller, CreateVmCommand, EXPIRATION, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";

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
  bytes32 private constant RANDOM_AUTHENTICATE = bytes32("Random value authenticate");
  bytes32 private constant RANDOM_RELATIONSHIP = bytes32("Random value relationship");
  bytes32 private constant DID_METHOD_0_CUSTOM = bytes32("method0_custom");
  bytes32 private constant DID_METHOD_1_CUSTOM = bytes32("method1_custom");
  bytes32 private constant DID_METHOD_2_CUSTOM = bytes32("method2_custom");
  bytes32 private constant VM_ID_CUSTOM = bytes32("vm_custom");
  bytes32 private constant VM_ID_CUSTOM_2 = bytes32("vm_custom_2");
  // Variables
  // -- users
  address admin = DEFAULT_SENDER;
  address user = payable(address(10));
  address otherUser = payable(address(11));
  address user1 = payable(address(12));
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

  function test_shouldNot_createDid_withRandomEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    //* 🎬 Act ⬇
    // Create DID
    vm.expectRevert("Random cannot be 0");
    didManager.createDid(
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_RANDOM, //! <-- Random value is empty
      EMPTY_VM_ID
    );
    //* ☑️ Assert ⬇
    // end
    vm.stopPrank();
  }

  // ! Not possible | really difficult in real newtorks
  function test_shouldNot_createDid_sameDidTwice() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 exp = didManager.getExpiration(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, block.timestamp + EXPIRATION);
    uint256 length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create DID
    vm.expectRevert("DID in use");
    didManager.createDid( // ! Same DID because params and block timestamp are the same
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  // ! Cannot be tested: if advance time to expire, the DID hash will change
  // function test_should_createDid_sameExpiredDid() public {

  // CREATE VERIFICATION METHOD
  function test_shouldNot_createVm_withMethod0Empty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert("Method0 cant be 0");
    CreateVmCommand memory command = CreateVmCommand({
      method0: EMPTY_DID_METHOD, // ! <-- Method0 is empty
      method1: EMPTY_DID_METHOD,
      method2: EMPTY_DID_METHOD,
      senderId: didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didInfo.id,
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKey: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      thisBcAddress: EMPTY_VM_THIS_BC_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE,
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withSenderIdEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert("DIDs cant be 0");
    CreateVmCommand memory command = CreateVmCommand({
      method0: didInfo.method0,
      method1: didInfo.method1,
      method2: didInfo.method2,
      senderId: EMPTY_DID_ID, // ! <-- Sender ID is empty
      senderVmId: DEFAULT_VM_ID,
      targetId: didInfo.id,
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKey: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      thisBcAddress: EMPTY_VM_THIS_BC_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE,
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withTargetIdEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert("DIDs cant be 0");
    CreateVmCommand memory command = CreateVmCommand({
      method0: didInfo.method0,
      method1: didInfo.method1,
      method2: didInfo.method2,
      senderId: didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: EMPTY_DID_ID, // ! <-- Target ID is empty
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKey: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      thisBcAddress: EMPTY_VM_THIS_BC_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE,
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withRelationshipsEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert("Relationships cant be 0");
    CreateVmCommand memory command = CreateVmCommand({
      method0: didInfo.method0,
      method1: didInfo.method1,
      method2: didInfo.method2,
      senderId: didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didInfo.id,
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKey: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      thisBcAddress: EMPTY_VM_THIS_BC_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE, // ! <-- Relationships are empty
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id
    );
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  // EXPIRE VERIFICATION METHOD

  function test_shouldNot_expireVm_withBadParameters() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 exp = didManager.getExpiration(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id,
      DEFAULT_VM_ID
    );
    assertEq(exp, block.timestamp + 365 days);
    //* 🎬 Act ⬇
    // Expire VM
    vm.expectRevert("Method0 cant be 0");
    didManager.expireVm(
      EMPTY_DID_METHOD, // ! <-- Method0 is empty
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      didInfo.id,
      VM_ID_CUSTOM,
      didInfo.id,
      DEFAULT_VM_ID
    );
    vm.expectRevert("DIDs cant be 0");
    didManager.expireVm({
      method0: didInfo.method0,
      method1: didInfo.method1,
      method2: didInfo.method2,
      senderId: EMPTY_DID_ID, // ! <-- Sender ID is empty
      senderVmId: VM_ID_CUSTOM,
      targetId: didInfo.id,
      vmId: DEFAULT_VM_ID
    });
    vm.expectRevert("DIDs cant be 0");
    didManager.expireVm({
      method0: didInfo.method0,
      method1: didInfo.method1,
      method2: didInfo.method2,
      senderId: didInfo.id,
      senderVmId: VM_ID_CUSTOM,
      targetId: EMPTY_DID_ID, // ! <-- Target ID is empty
      vmId: DEFAULT_VM_ID
    });
    //* ☑️ Assert ⬇
    // Check final state
    exp = didManager.getExpiration(
      didInfo.method0,
      didInfo.method1,
      didInfo.method2,
      didInfo.id,
      DEFAULT_VM_ID
    );
    assertEq(exp, block.timestamp + 365 days);
    // end
    vm.stopPrank();
  }

  // UPDATE CONTROLLER
  function test_should_updateController_ownController() public {
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

  function test_should_updateController_otherController() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory userDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    (DidInfo memory otherDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: userDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id,
      controllerId: otherDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    // Update controller from other user VM
    command = UpdateControllerCommandTest({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: otherDid.id, // <-- other user
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id, // <-- is changing the controller of the user
      controllerId: userDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    _updateController(command);
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    assertEq(controllers[1].id, userDid.id);
    assertEq(controllers[1].vmId, DEFAULT_VM_ID);
    for (uint8 i = 2; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  function test_should_updateController_positionGtMax() public {
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
      controllerPosition: CONTROLLERS_MAX_LENGTH // * <-- Last position + 1
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
    assertEq(controllers[CONTROLLERS_MAX_LENGTH - 1].id, defaultDid.id);
    assertEq(controllers[CONTROLLERS_MAX_LENGTH - 1].vmId, DEFAULT_VM_ID);
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH - 1; i++) {
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

  function test_shouldNot_updateController_withBadParameters() public {
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
    vm.expectRevert("Method0 cant be 0");
    didManager.updateController({
      method0: EMPTY_DID_METHOD, // ! <-- Method0 is empty
      method1: defaultDid.method1,
      method2: defaultDid.method2,
      senderId: defaultDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: defaultDid.id,
      controllerId: defaultDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    vm.expectRevert("DIDs cant be 0");
    didManager.updateController({
      method0: defaultDid.method0,
      method1: defaultDid.method1,
      method2: defaultDid.method2,
      senderId: EMPTY_DID_ID, // ! <-- Sender ID is empty
      senderVmId: DEFAULT_VM_ID,
      targetId: defaultDid.id,
      controllerId: defaultDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    vm.expectRevert("DIDs cant be 0");
    didManager.updateController({
      method0: defaultDid.method0,
      method1: defaultDid.method1,
      method2: defaultDid.method2,
      senderId: defaultDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: EMPTY_DID_ID, // ! <-- Target ID is empty
      controllerId: defaultDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    vm.expectRevert("DIDs cant be 0");
    didManager.updateController({
      method0: defaultDid.method0,
      method1: defaultDid.method1,
      method2: defaultDid.method2,
      senderId: defaultDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: defaultDid.id,
      controllerId: EMPTY_DID_ID, // ! <-- Controller ID is empty
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(
      defaultDid.method0,
      defaultDid.method1,
      defaultDid.method2,
      defaultDid.id
    );
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    // end
    vm.stopPrank();
  }

  // _validateSenderAndTarget()
  function test_shouldNot_updateController_withSenderIdExpired() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory userDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    (DidInfo memory otherDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: userDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id,
      controllerId: otherDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    // Expire sender VM
    vm.warp(block.timestamp + EXPIRATION + 1); // ! advance time
    //* 🎬 Act ⬇
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    vm.expectRevert("Sender DID expired");
    didManager.updateController({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: otherDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id,
      controllerId: userDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  function test_shouldNot_updateController_withAnotherSender() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory userDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    (DidInfo memory otherDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: userDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id,
      controllerId: otherDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    startHoax(user, DEFAULT_USER_BALANCE); // ! Sender now is the user
    vm.expectRevert("Not authenticated as sender");
    didManager.updateController({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: otherDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id,
      controllerId: userDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  function test_shouldNot_updateController_withNoControllerForTarget() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory userDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    (DidInfo memory otherDid, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    startHoax(user1, DEFAULT_USER_BALANCE);
    (DidInfo memory user1Did, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      VM_ID_CUSTOM
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: userDid.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userDid.id,
      controllerId: otherDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    startHoax(user1, DEFAULT_USER_BALANCE);
    vm.expectRevert("Not a controller for target");
    didManager.updateController({
      method0: userDid.method0,
      method1: userDid.method1,
      method2: userDid.method2,
      senderId: user1Did.id,
      senderVmId: VM_ID_CUSTOM, // ! <-- Other user Custom VM is not registered in user's DID
      targetId: userDid.id,
      controllerId: userDid.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(
      userDid.method0,
      userDid.method1,
      userDid.method2,
      userDid.id
    );
    assertEq(controllers[0].id, otherDid.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  // READ FUNCTIONS
  function test_should_authenticateVm() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory did, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_AUTHENTICATE,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Authenticate VM
    bool authenticated = didManager.authenticate(
      did.method0,
      did.method1,
      did.method2,
      did.id,
      DEFAULT_VM_ID,
      user
    );
    //* ☑️ Assert ⬇
    assert(authenticated);
    // end
    vm.stopPrank();
  }

  function test_should_checkVmRelationship() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory did, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_RELATIONSHIP,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Authenticate VM
    bool isRelationship = didManager.isVmRelationship(
      did.method0,
      did.method1,
      did.method2,
      did.id,
      DEFAULT_VM_ID,
      VM_RELATIONSHIPS_AUTHENTICATION,
      user
    );
    //* ☑️ Assert ⬇
    assert(isRelationship);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_checkVmRelationship_withBadParams() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    (DidInfo memory did, , , , , , ) = _createDid(
      didManager,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_RELATIONSHIP,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Authenticate VM
    vm.expectRevert("Method0 cant be 0");
    bool isRelationship = didManager.isVmRelationship(
      EMPTY_DID_METHOD, // ! <-- Method0 is empty
      did.method1,
      did.method2,
      did.id,
      DEFAULT_VM_ID,
      VM_RELATIONSHIPS_AUTHENTICATION,
      user
    );
    vm.expectRevert("ID cant be 0");
    isRelationship = didManager.isVmRelationship(
      did.method0,
      did.method1,
      did.method2,
      EMPTY_DID_ID, // ! <-- ID is empty
      DEFAULT_VM_ID,
      VM_RELATIONSHIPS_AUTHENTICATION,
      user
    );
    vm.expectRevert("Sender cant be 0");
    isRelationship = didManager.isVmRelationship(
      did.method0,
      did.method1,
      did.method2,
      did.id,
      DEFAULT_VM_ID,
      VM_RELATIONSHIPS_AUTHENTICATION,
      EMPTY_SENDER // ! <-- Sender is empty
    );
    //* ☑️ Assert ⬇
    assert(!isRelationship);
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
