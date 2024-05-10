// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, CreateVmCommand as DidCreateVmCommand } from "@src/interfaces/IDidManager.sol";
import { DidManager } from "@src/DidManager.sol";
import { VMStorage, VerificationMethod, CreateVmCommand } from "@src/VMStorage.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";

contract VMStorageTest is SharedTest {
  //* Constants
  // General
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  uint256 private constant INIT_CONTRACTS = 6;
  // Specific
  address private constant RANDOM_VM_THIS_BC_ADDRESS = address(666);
  bytes1 private constant DEFAULT_VM_RELATIONSHIPS = VM_RELATIONSHIPS_AUTHENTICATION;
  bytes32[10] VM_ID = [bytes32("vm-create-test"), bytes32("vm-validate-test")];
  // Variables
  address private DEFAULT_VM_THIS_BC_ADDRESS;
  uint256 private DEFAULT_VM_EXPIRATION;
  // -- users
  address admin = DEFAULT_SENDER;
  address user = payable(address(10));
  address otherUser = payable(address(11));
  // -- contracts
  uint256 lastDidManagerUsed;
  IDidManager didManager;
  DidInfo userDidInfo;
  DidInfo otherUserDidInfo;

  /**
   * @dev Sets up the test environment by transferring some ether to users and deploying the DidManager contract.
   */
  function setUp() public {
    DEFAULT_VM_THIS_BC_ADDRESS = user;
    DEFAULT_VM_EXPIRATION = block.timestamp + 60; // Now + 1 minute
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
      didManager,
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32("random0"),
      bytes32(0)
    );
    vm.stopPrank();
    // Create a DID for other user
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    (otherUserDidInfo, , , , , , ) = _createDid(
      didManager,
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32("random1"),
      bytes32(0)
    );
    vm.stopPrank();
  }

  //* TESTS
  // CREATE VERIFICATION METHOD
  function test_should_createVm() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VM_ID[0],
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    //* 🎬 Act ⬇
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmCreated_idHash,
      bytes32 VmCreated_positionHash
    ) = _createVm(command);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    bytes32 expectedVmIdHash = keccak256(abi.encodePacked(didData.idHash, VM_ID[0]));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(didData.idHash, uint8(2)));
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      command.vmId,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    // Check Events
    // event VmCreated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed idHash,
    //   bytes32 positionHash
    // );
    assertEq(VmCreated_didIdHash, didData.idHash);
    assertEq(VmCreated_id, command.vmId);
    assertEq(VmCreated_idHash, expectedVmIdHash);
    assertEq(VmCreated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_should_createVm_WithPublicKey() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VM_ID[0],
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    //* 🎬 Act ⬇
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      DEFAULT_VM_PUBLIC_KEY, // ! <== Public Key
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID, // * <-- important
      EMPTY_VM_THIS_BC_ADDRESS, // * <-- important
      DEFAULT_VM_RELATIONSHIPS,
      DEFAULT_VM_EXPIRATION // * <-- important
    );
    (
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmCreated_idHash,
      bytes32 VmCreated_positionHash
    ) = _createVm(command);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    bytes32 expectedVmIdHash = keccak256(abi.encodePacked(didData.idHash, VM_ID[0]));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(didData.idHash, uint8(2)));
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      command.vmId,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    // Check Events
    // event VmCreated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed idHash,
    //   bytes32 positionHash
    // );
    assertEq(VmCreated_didIdHash, didData.idHash);
    assertEq(VmCreated_id, command.vmId);
    assertEq(VmCreated_idHash, expectedVmIdHash);
    assertEq(VmCreated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_should_createVm_WithBlockchainAccountId() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VM_ID[0],
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    //* 🎬 Act ⬇
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY, // * <-- important
      DEFAULT_VM_BLOCKCHAIN_ACCOUNT_ID, // ! <== Blockchain Account ID
      EMPTY_VM_THIS_BC_ADDRESS, // * <-- important
      DEFAULT_VM_RELATIONSHIPS,
      DEFAULT_VM_EXPIRATION // * <-- important
    );
    (
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmCreated_idHash,
      bytes32 VmCreated_positionHash
    ) = _createVm(command);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    bytes32 expectedVmIdHash = keccak256(abi.encodePacked(didData.idHash, VM_ID[0]));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(didData.idHash, uint8(2)));
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      command.vmId,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    // Check Events
    // event VmCreated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed idHash,
    //   bytes32 positionHash
    // );
    assertEq(VmCreated_didIdHash, didData.idHash);
    assertEq(VmCreated_id, command.vmId);
    assertEq(VmCreated_idHash, expectedVmIdHash);
    assertEq(VmCreated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_should_createVm_andChangeExpirationTo0() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VM_ID[0],
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    //* 🎬 Act ⬇
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS, // * <-- important
      DEFAULT_VM_RELATIONSHIPS,
      DEFAULT_VM_EXPIRATION // * <-- important: should change to 0
    );
    (
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmCreated_idHash,
      bytes32 VmCreated_positionHash
    ) = _createVm(command);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    bytes32 expectedVmIdHash = keccak256(abi.encodePacked(didData.idHash, VM_ID[0]));
    bytes32 expectedPositionHash = keccak256(abi.encodePacked(didData.idHash, uint8(2)));
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        EMPTY_VM_EXPIRATION
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      command.vmId,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        EMPTY_VM_EXPIRATION
      )
    );
    // Check Events
    // event VmCreated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed idHash,
    //   bytes32 positionHash
    // );
    assertEq(VmCreated_didIdHash, didData.idHash);
    assertEq(VmCreated_id, command.vmId);
    assertEq(VmCreated_idHash, expectedVmIdHash);
    assertEq(VmCreated_positionHash, expectedPositionHash);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_createVm_withPubKeyBlockchainAccountIdAndThisBcAddressEmpty() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    assertEq(length, 1);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VM_ID[0],
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    //* 🎬 Act ⬇
    // Add new Verification Method
    vm.expectRevert("4th or 5th or 6th param required");
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY, //! <== Empty
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID, //! <== Empty
      EMPTY_VM_THIS_BC_ADDRESS, //! <== Empty
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    didManager.createVm(command);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 1);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      command.vmId,
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    // end
    vm.stopPrank();
  }

  // VALIDATE VERIFICATION METHOD
  function test_should_validateVm() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , bytes32 VmCreated_positionHash) = _createVm(command);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    //* 🎬 Act ⬇
    // Validate Verification Method
    bytes32 VmValidated_id = _validateVm(VmCreated_positionHash, DEFAULT_VM_EXPIRATION);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmValidated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    // Check Events
    // event VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, VM_ID[0]);
    assertEq(VmValidated_id, VmCreated_id);
    // end
    vm.stopPrank();
  }

  function test_should_validateVm_withExpEmpty() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , bytes32 VmCreated_positionHash) = _createVm(command);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    //* 🎬 Act ⬇
    // Validate Verification Method
    bytes32 VmValidated_id = _validateVm(VmCreated_positionHash, EMPTY_VM_EXPIRATION);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        block.timestamp + 365 days
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmValidated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        block.timestamp + 365 days
      )
    );
    // Check Events
    // event VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, VM_ID[0]);
    assertEq(VmValidated_id, VmCreated_id);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_validateVm_withOtherVmPositionHash() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , ) = _createVm(command);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    //* 🎬 Act ⬇
    // Validate Verification Method
    vm.expectRevert("VM not found");
    didManager.validateVm(keccak256("Does Not Exist"), DEFAULT_VM_EXPIRATION);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        EMPTY_VM_EXPIRATION
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        EMPTY_VM_EXPIRATION
      )
    );
    // end
    vm.stopPrank();
  }

  function test_shouldNot_validateVm_withNoThisBcAddress() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      DEFAULT_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      EMPTY_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      DEFAULT_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , bytes32 VmCreated_positionHash) = _createVm(command);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    //* 🎬 Act ⬇
    // Validate Verification Method
    vm.expectRevert("VM already validated or out");
    didManager.validateVm(VmCreated_positionHash, DEFAULT_VM_EXPIRATION);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    // end
    vm.stopPrank();
  }

  function test_shouldNot_validateVm_withOtherSender() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , bytes32 VmCreated_positionHash) = _createVm(command);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        command.expiration
      )
    );
    //* 🎬 Act ⬇
    // Validate Verification Method
    vm.expectRevert("Cant validate VM. Invalid Sign");
    startHoax(otherUser, DEFAULT_USER_BALANCE);
    didManager.validateVm(VmCreated_positionHash, DEFAULT_VM_EXPIRATION);
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        EMPTY_VM_EXPIRATION
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        EMPTY_VM_EXPIRATION
      )
    );
    // end
    vm.stopPrank();
  }

  // VALIDATE VERIFICATION METHOD
  function test_should_expireVm() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , bytes32 VmCreated_positionHash) = _createVm(command);
    _validateVm(VmCreated_positionHash, DEFAULT_VM_EXPIRATION);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    //* 🎬 Act ⬇
    // Expire Verification Method
    (
      bytes32 VmExpirationUpdated_didIdHash,
      bytes32 VmExpirationUpdated_id,
      bool VmExpirationUpdated_expired,
      uint256 VmExpirationUpdated_expiration
    ) = _expireVm(
        didData.method0,
        didData.method1,
        didData.method2,
        didData.id, // sender ID
        DEFAULT_VM_ID, // sender VM ID
        command.targetId, // target ID
        command.vmId // VM ID to expire
      );
    //* ☑️ Assert ⬇
    // Final length
    length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Check final state
    assertEq(length, 2);
    // -- final "first vm"
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        VmExpirationUpdated_expiration
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        VmExpirationUpdated_expiration
      )
    );
    // Check Events
    // event VmExpirationUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bool indexed expired,
    //   uint256 expiration
    // );
    assertEq(VmExpirationUpdated_didIdHash, didData.idHash);
    assertEq(VmExpirationUpdated_id, command.vmId);
    assertEq(VmExpirationUpdated_expired, true);
    assertEq(VmExpirationUpdated_expiration, block.timestamp);
    // end
    vm.stopPrank();
  }

  function test_shouldNot_expireVm_alreadyExpired() public {
    //* 🗂️ Arrange ⬇
    DidInfo memory didData = userDidInfo;
    startHoax(user, DEFAULT_USER_BALANCE);
    // Add new Verification Method
    DidCreateVmCommand memory command = DidCreateVmCommand(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      DEFAULT_VM_ID,
      didData.id,
      VM_ID[0],
      DEFAULT_VM_TYPE,
      EMPTY_VM_PUBLIC_KEY,
      EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID,
      DEFAULT_VM_THIS_BC_ADDRESS,
      DEFAULT_VM_RELATIONSHIPS,
      EMPTY_VM_EXPIRATION
    );
    (, bytes32 VmCreated_id, , bytes32 VmCreated_positionHash) = _createVm(command);
    _validateVm(VmCreated_positionHash, DEFAULT_VM_EXPIRATION);
    // Check previous state
    uint256 length = didManager.getVmListLength(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      didData.id
    );
    // Should be the one by default when creating DID + the one we just added
    assertEq(length, 2);
    VerificationMethod memory verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        DEFAULT_VM_EXPIRATION
      )
    );
    // Expire Verification Method
    _expireVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id, // sender ID
      DEFAULT_VM_ID, // sender VM ID
      command.targetId, // target ID
      command.vmId // VM ID to expire
    );

    //* 🎬 Act ⬇
    // Expire Verification Method
    vm.expectRevert("VM already expired");
    didManager.expireVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id, // sender ID
      DEFAULT_VM_ID, // sender VM ID
      command.targetId, // target ID
      command.vmId // VM ID to expire
    );
    //* ☑️ Assert ⬇
    // -- final vm by ID
    verificationMethod = didManager.getVm(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VmCreated_id,
      uint8(0)
    );
    _assertVm(
      verificationMethod,
      VerificationMethod(
        command.vmId,
        command.type_,
        command.publicKey,
        command.blockchainAccountId,
        command.ethereumAddress,
        command.relationships,
        block.number
      )
    );
    // end
    vm.stopPrank();
  }

  // * Internal functions

  /**
   * @dev Creates a new verification method.
   */
  function _createVm(
    DidCreateVmCommand memory command
  )
    internal
    returns (
      bytes32 VmCreated_didIdHash,
      bytes32 VmCreated_id,
      bytes32 VmCreated_idHash,
      bytes32 VmCreated_positionHash
    )
  {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.createVm(command);
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // event VmCreated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed idHash,
    //   bytes32 positionHash
    // );
    VmCreated_didIdHash = entries[0].topics[1];
    VmCreated_id = entries[0].topics[2];
    VmCreated_idHash = entries[0].topics[3];
    VmCreated_positionHash = bytes32(entries[0].data);
  }

  function _validateVm(
    bytes32 positionHash,
    uint expiration
  ) internal returns (bytes32 VmValidated_id) {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.validateVm(positionHash, expiration);
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // event VmValidated(bytes32 indexed id);
    VmValidated_id = entries[0].topics[1];
  }

  function _expireVm(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 vmId
  )
    private
    returns (
      bytes32 VmExpirationUpdated_didIdHash,
      bytes32 VmExpirationUpdated_id,
      bool VmExpirationUpdated_expired,
      uint256 VmExpirationUpdated_expiration
    )
  {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.expireVm(method0, method1, method2, senderId, senderVmId, targetId, vmId);
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // event VmExpirationUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bool indexed expired,
    //   uint256 expiration
    // );
    VmExpirationUpdated_didIdHash = entries[0].topics[1];
    VmExpirationUpdated_id = entries[0].topics[2];
    VmExpirationUpdated_expired = entries[0].topics[3] != bytes32(0);
    VmExpirationUpdated_expiration = uint256(bytes32(entries[0].data));
  }

  function _assertEmptyVm(VerificationMethod memory verificationMethod) internal {
    assertEq(verificationMethod.id, bytes32(0));
    for (uint256 i = 0; i < 2; i++) {
      assertEq(verificationMethod.type_[i], bytes32(0));
    }
    for (uint256 i = 0; i < 16; i++) {
      assertEq(verificationMethod.publicKey[i], bytes32(0));
    }
    for (uint256 i = 0; i < 5; i++) {
      assertEq(verificationMethod.blockchainAccountId[i], bytes32(0));
    }
    assertEq(verificationMethod.ethereumAddress, address(0));
    assertEq(verificationMethod.relationships, bytes1(0));
    assertEq(verificationMethod.expiration, 0);
  }

  function _assertVm(
    VerificationMethod memory vmToCheck,
    VerificationMethod memory expectedVM
  ) internal {
    assertEq(vmToCheck.id, expectedVM.id);
    for (uint256 i = 0; i < 2; i++) {
      assertEq(vmToCheck.type_[i], expectedVM.type_[i]);
    }
    for (uint256 i = 0; i < 16; i++) {
      assertEq(vmToCheck.publicKey[i], expectedVM.publicKey[i]);
    }
    for (uint256 i = 0; i < 5; i++) {
      assertEq(vmToCheck.blockchainAccountId[i], expectedVM.blockchainAccountId[i]);
    }
    assertEq(vmToCheck.ethereumAddress, expectedVM.ethereumAddress);
    assertEq(vmToCheck.relationships, expectedVM.relationships);
    assertEq(vmToCheck.expiration, expectedVM.expiration);
  }
}
