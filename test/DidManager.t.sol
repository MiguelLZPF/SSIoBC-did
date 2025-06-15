// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { SharedTest, DidInfo, CreateDidResultTest } from "@test/SharedTest.sol";
import { IVMStorage } from "@src/interfaces/IVMStorage.sol";
import { IDidManager, VerificationMethod, Controller, CreateVmCommand, EXPIRATION, CONTROLLERS_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";

struct UpdateControllerCommandTest {
  bytes32 methods;
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
  // Specific
  bytes32 private constant RANDOM_AUTHENTICATE = bytes32("Random value authenticate");
  bytes32 private constant RANDOM_RELATIONSHIP = bytes32("Random value relationship");
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
      abi.encodePacked(DEFAULT_DID_METHODS, DEFAULT_RANDOM_0, tx.origin, block.prevrandao)
    );
    uint256 exp = didManager.getExpiration(
      DEFAULT_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(DEFAULT_DID_METHODS, id);
    assertEq(length, 0);
    //* 🎬 Act ⬇
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    //* ☑️ Assert ⬇
    // Check final state
    exp = didManager.getExpiration(
      DEFAULT_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, block.timestamp + EXPIRATION);
    length = didManager.getVmListLength(DEFAULT_DID_METHODS, id);
    assertEq(length, 1);
    // Check Events
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    assertEq(result.VmCreated_didIdHash, _calculateDidHash(DEFAULT_DID_METHODS, id));
    assertEq(result.VmCreated_id, DEFAULT_VM_ID);
    // VmValidated(bytes32 indexed id);
    assertEq(result.VmValidated_id, DEFAULT_VM_ID);
    assertEq(result.VmCreated_id, result.VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash);
    assertEq(result.DidCreated_id, id);
    assertEq(result.DidCreated_idHash, _calculateDidHash(DEFAULT_DID_METHODS, id));
    assertEq(result.DidCreated_idHash, result.VmCreated_didIdHash);
    // end
    vm.stopPrank();
  }

  function test_should_createDid_withCustomParams() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check initial state
    // ! Not possible | really difficult in real newtorks
    bytes32 id = keccak256(
      abi.encodePacked(CUSTOM_DID_METHODS, DEFAULT_RANDOM_0, tx.origin, block.prevrandao)
    );
    uint256 exp = didManager.getExpiration(
      CUSTOM_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(CUSTOM_DID_METHODS, id);
    assertEq(length, 0);
    //* 🎬 Act ⬇
    // Create DID
    CreateDidResultTest memory result = _createDid(
      CUSTOM_DID_METHODS,
      DEFAULT_RANDOM_0,
      VM_ID_CUSTOM
    );
    //* ☑️ Assert ⬇
    // Check final state
    exp = didManager.getExpiration(
      CUSTOM_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, block.timestamp + EXPIRATION);
    length = didManager.getVmListLength(CUSTOM_DID_METHODS, id);
    assertEq(length, 1);
    // Check Events
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    assertEq(result.VmCreated_didIdHash, _calculateDidHash(CUSTOM_DID_METHODS, id));
    assertEq(result.VmCreated_id, VM_ID_CUSTOM);
    // VmValidated(bytes32 indexed id);
    assertEq(result.VmValidated_id, VM_ID_CUSTOM);
    assertEq(result.VmCreated_id, result.VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertEq(result.DidCreated_id, id);
    assertEq(result.DidCreated_idHash, _calculateDidHash(CUSTOM_DID_METHODS, id));
    assertEq(result.DidCreated_idHash, result.VmCreated_didIdHash);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createDid_withRandomEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    //* 🎬 Act ⬇
    // Create DID
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.createDid(
      EMPTY_DID_METHODS,
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
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 exp = didManager.getExpiration(
      result.didInfo.methods,
      result.didInfo.id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, block.timestamp + EXPIRATION);
    uint256 length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create DID
    vm.expectRevert(IDidManager.DidAlreadyExists.selector);
    didManager.createDid(EMPTY_DID_METHODS, DEFAULT_RANDOM_0, EMPTY_VM_ID); // ! Same DID because params and block timestamp are the same
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
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
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    CreateVmCommand memory command = CreateVmCommand({
      methods: EMPTY_DID_METHODS, // ! <-- Method0 is empty
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKeyMultibase: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      ethereumAddress: EMPTY_VM_ETHEREUM_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE,
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withSenderIdEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    CreateVmCommand memory command = CreateVmCommand({
      methods: result.didInfo.methods, // ! <-- Updated to use methods
      senderId: EMPTY_DID_ID, // ! <-- Sender ID is empty
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKeyMultibase: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      ethereumAddress: EMPTY_VM_ETHEREUM_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE,
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withTargetIdEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    CreateVmCommand memory command = CreateVmCommand({
      methods: result.didInfo.methods, // ! <-- Updated to use methods
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: EMPTY_DID_ID, // ! <-- Target ID is empty
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKeyMultibase: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      ethereumAddress: EMPTY_VM_ETHEREUM_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE,
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withRelationshipsEmpty() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    //* 🎬 Act ⬇
    // Create VM
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    CreateVmCommand memory command = CreateVmCommand({
      methods: result.didInfo.methods, // ! <-- Updated to use methods
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      vmId: VM_ID_CUSTOM,
      type_: EMPTY_VM_TYPE,
      publicKeyMultibase: EMPTY_VM_PUBLIC_KEY,
      blockchainAccountId: EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      ethereumAddress: EMPTY_VM_ETHEREUM_ADDRESS,
      relationships: VM_RELATIONSHIPS_NONE, // ! <-- Relationships are empty
      expiration: EMPTY_VM_EXPIRATION
    });
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Check final state
    length = didManager.getVmListLength(result.didInfo.methods, result.didInfo.id);
    assertEq(length, 1);
    // end
    vm.stopPrank();
  }

  // EXPIRE VERIFICATION METHOD

  function test_shouldNot_expireVm_withBadParameters() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    uint256 exp = didManager.getExpiration(
      result.didInfo.methods,
      result.didInfo.id,
      DEFAULT_VM_ID
    );
    assertEq(exp, block.timestamp + 365 days);
    //* 🎬 Act ⬇
    // Expire VM
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.expireVm(
      EMPTY_DID_METHODS, // ! <-- Updated to use methods
      result.didInfo.id,
      VM_ID_CUSTOM,
      result.didInfo.id,
      DEFAULT_VM_ID
    );
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.expireVm({
      methods: result.didInfo.methods, // ! <-- Updated to use methods
      senderId: EMPTY_DID_ID, // ! <-- Sender ID is empty
      senderVmId: VM_ID_CUSTOM,
      targetId: result.didInfo.id,
      vmId: DEFAULT_VM_ID
    });
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.expireVm({
      methods: result.didInfo.methods,
      senderId: result.didInfo.id,
      senderVmId: VM_ID_CUSTOM,
      targetId: EMPTY_DID_ID, // ! <-- Target ID is empty
      vmId: DEFAULT_VM_ID
    });
    //* ☑️ Assert ⬇
    // Check final state
    exp = didManager.getExpiration(result.didInfo.methods, result.didInfo.id, DEFAULT_VM_ID);
    assertEq(exp, block.timestamp + 365 days);
    // end
    vm.stopPrank();
  }

  // UPDATE CONTROLLER
  function test_should_updateController_ownController() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      result.didInfo.methods, // ! <-- Updated to use methods
      result.didInfo.id
    );
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    // Update controller
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      methods: result.didInfo.methods, // ! <-- Updated to use methods
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      controllerId: result.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    UpdateControllerResponseTest memory res = _updateController(command);
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(result.didInfo.methods, result.didInfo.id);
    assertEq(controllers[0].id, result.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    // Check Events
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, uint8 controllerPosition, bytes32 method0, bytes32 method1, bytes32 method2, bytes32 id, bytes32 vmId)
    assertEq(
      res.ControllerUpdated_senderDidHash,
      _calculateDidHash(result.didInfo.methods, result.didInfo.id)
    );
    assertEq(
      res.ControllerUpdated_targetDidHash,
      _calculateDidHash(result.didInfo.methods, result.didInfo.id)
    );
    assertEq(res.ControllerUpdated_senderDidHash, result.didInfo.idHash);
    assertEq(res.ControllerUpdated_targetDidHash, result.didInfo.idHash);
    // end
    vm.stopPrank();
  }

  function test_should_updateController_otherController() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory userResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory otherResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_1,
      EMPTY_VM_ID
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      methods: userResult.didInfo.methods,
      senderId: userResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id,
      controllerId: otherResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userResult.didInfo.methods,
      userResult.didInfo.id
    );
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    // Update controller from other user VM
    command = UpdateControllerCommandTest({
      methods: userResult.didInfo.methods,
      senderId: otherResult.didInfo.id, // <-- other user
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id, // <-- is changing the controller of the user
      controllerId: userResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    _updateController(command);
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(userResult.didInfo.methods, userResult.didInfo.id);
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    assertEq(controllers[1].id, userResult.didInfo.id);
    assertEq(controllers[1].vmId, DEFAULT_VM_ID);
    for (uint8 i = 2; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  function test_should_updateController_positionGtMax() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      result.didInfo.methods,
      result.didInfo.id
    );
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    // Update controller
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      methods: result.didInfo.methods,
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      controllerId: result.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: CONTROLLERS_MAX_LENGTH // * <-- Last position + 1
    });
    UpdateControllerResponseTest memory res = _updateController(command);
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(result.didInfo.methods, result.didInfo.id);
    assertEq(controllers[CONTROLLERS_MAX_LENGTH - 1].id, result.didInfo.id);
    assertEq(controllers[CONTROLLERS_MAX_LENGTH - 1].vmId, DEFAULT_VM_ID);
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH - 1; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    // Check Events
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, uint8 controllerPosition, bytes32 method0, bytes32 method1, bytes32 method2, bytes32 id, bytes32 vmId)
    assertEq(
      res.ControllerUpdated_senderDidHash,
      _calculateDidHash(result.didInfo.methods, result.didInfo.id)
    );
    assertEq(
      res.ControllerUpdated_targetDidHash,
      _calculateDidHash(result.didInfo.methods, result.didInfo.id)
    );
    assertEq(res.ControllerUpdated_senderDidHash, result.didInfo.idHash);
    assertEq(res.ControllerUpdated_targetDidHash, result.didInfo.idHash);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_updateController_withBadParameters() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      result.didInfo.methods,
      result.didInfo.id
    );
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    // Update controller
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.updateController({
      methods: EMPTY_DID_METHODS, // ! <-- Method0 is empty
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      controllerId: result.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.updateController({
      methods: result.didInfo.methods,
      senderId: EMPTY_DID_ID, // ! <-- Sender ID is empty
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      controllerId: result.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.updateController({
      methods: result.didInfo.methods,
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: EMPTY_DID_ID, // ! <-- Target ID is empty
      controllerId: result.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    didManager.updateController({
      methods: result.didInfo.methods,
      senderId: result.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: result.didInfo.id,
      controllerId: EMPTY_DID_ID, // ! <-- Controller ID is empty
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(result.didInfo.methods, result.didInfo.id);
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
    CreateDidResultTest memory userResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory otherResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_1,
      EMPTY_VM_ID
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      methods: userResult.didInfo.methods,
      senderId: userResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id,
      controllerId: otherResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userResult.didInfo.methods,
      userResult.didInfo.id
    );
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    // Expire sender VM
    vm.warp(block.timestamp + EXPIRATION + 1); // ! advance time
    //* 🎬 Act ⬇
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    vm.expectRevert(IDidManager.DidExpired.selector);
    didManager.updateController({
      methods: userResult.didInfo.methods,
      senderId: otherResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id,
      controllerId: userResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(userResult.didInfo.methods, userResult.didInfo.id);
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  function test_shouldNot_updateController_withAnotherSender() public {
    //* 🗂️ Arrange ⬇
    vm.deal(user, DEFAULT_USER_BALANCE);
    vm.startPrank(user, user); // Set user as the sender & origin
    CreateDidResultTest memory userResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    vm.stopPrank();

    vm.deal(otherUser, DEFAULT_USER_BALANCE);
    vm.startPrank(otherUser, otherUser); // Set other user as the sender & origin
    CreateDidResultTest memory otherResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_1,
      EMPTY_VM_ID
    );
    vm.stopPrank();

    vm.startPrank(user, user); // Set user as the sender & origin
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      methods: userResult.didInfo.methods,
      senderId: userResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id,
      controllerId: otherResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userResult.didInfo.methods,
      userResult.didInfo.id
    );
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    vm.startPrank(user, user); // ! Sender & origin now is the user
    console.logBytes32(otherResult.didInfo.id);
    console.log(msg.sender);
    console.log(tx.origin);
    vm.expectRevert(IDidManager.NotAuthenticatedAsSenderId.selector);
    didManager.updateController({
      methods: userResult.didInfo.methods,
      senderId: otherResult.didInfo.id, //! <-- Other user is trying to update the controller
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id,
      controllerId: userResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(userResult.didInfo.methods, userResult.didInfo.id);
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  function test_shouldNot_updateController_withNoControllerForTarget() public {
    //* 🗂️ Arrange ⬇
    startHoax(user, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory userResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_0,
      EMPTY_VM_ID
    );
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory otherResult = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_1,
      EMPTY_VM_ID
    );
    startHoax(user1, DEFAULT_USER_BALANCE);
    CreateDidResultTest memory user1Result = _createDid(
      EMPTY_DID_METHODS,
      DEFAULT_RANDOM_2,
      VM_ID_CUSTOM
    );
    startHoax(user, DEFAULT_USER_BALANCE);
    // Update controller with other user VM
    UpdateControllerCommandTest memory command = UpdateControllerCommandTest({
      methods: userResult.didInfo.methods,
      senderId: userResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: userResult.didInfo.id,
      controllerId: otherResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 0
    });
    _updateController(command);
    // Check initial state
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = didManager.getControllerList(
      userResult.didInfo.methods,
      userResult.didInfo.id
    );
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
    //* 🎬 Act ⬇
    startHoax(user1, DEFAULT_USER_BALANCE);
    vm.expectRevert(IDidManager.NotAControllerforTargetId.selector);
    didManager.updateController({
      methods: userResult.didInfo.methods,
      senderId: user1Result.didInfo.id,
      senderVmId: VM_ID_CUSTOM, // ! <-- Other user Custom VM is not registered in user's DID
      targetId: userResult.didInfo.id,
      controllerId: userResult.didInfo.id,
      controllerVmId: DEFAULT_VM_ID,
      controllerPosition: 1
    });
    //* ☑️ Assert ⬇
    // Check final state
    controllers = didManager.getControllerList(userResult.didInfo.methods, userResult.didInfo.id);
    assertEq(controllers[0].id, otherResult.didInfo.id);
    assertEq(controllers[0].vmId, DEFAULT_VM_ID);
    for (uint8 i = 1; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(controllers[i].id, EMPTY_DID_ID);
      assertEq(controllers[i].vmId, EMPTY_VM_ID);
    }
  }

  // READ FUNCTIONS
  function test_should_authenticateVm() public {
    //* 🗂️ Arrange ⬇
    vm.deal(user, DEFAULT_USER_BALANCE);
    vm.startPrank(user, user); // Set user as the sender & origin
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      RANDOM_AUTHENTICATE,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Authenticate VM
    bool authenticated = didManager.authenticate(
      result.didInfo.methods,
      result.didInfo.id,
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
    vm.deal(user, DEFAULT_USER_BALANCE);
    vm.startPrank(user, user);
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      RANDOM_RELATIONSHIP,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Authenticate VM
    bool isRelationship = didManager.isVmRelationship(
      result.didInfo.methods,
      result.didInfo.id,
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
    vm.deal(user, DEFAULT_USER_BALANCE);
    vm.startPrank(user, user);
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      RANDOM_RELATIONSHIP,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Authenticate VM
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    bool isRelationship = didManager.isVmRelationship(
      EMPTY_DID_METHODS, // ! <-- Method0 is empty
      result.didInfo.id,
      DEFAULT_VM_ID,
      VM_RELATIONSHIPS_AUTHENTICATION,
      user
    );
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    isRelationship = didManager.isVmRelationship(
      result.didInfo.methods,
      EMPTY_DID_ID, // ! <-- ID is empty
      DEFAULT_VM_ID,
      VM_RELATIONSHIPS_AUTHENTICATION,
      user
    );
    vm.expectRevert(IVMStorage.MissingRequiredParameter.selector);
    isRelationship = didManager.isVmRelationship(
      result.didInfo.methods,
      result.didInfo.id,
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
      command.methods,
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
