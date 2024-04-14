// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, CreateVmCommand as DidCreateVmCommand, REVERT_NOT_CONTROLLER } from "@src/interfaces/IDidManager.sol";
import { DidManager } from "@src/DidManager.sol";
import { VMStorage, VerificationMethod, CreateVmCommand } from "@src/VMStorage.sol";
import { SharedTest, DidInfo } from "@test/SharedTest.sol";

contract VMStorageTest is SharedTest {
  //* Constants
  // General
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  uint256 private constant INIT_CONTRACTS = 6;
  // Specific
  bytes32[2] private EMPTY_VM_TYPE = [bytes32(0)];
  bytes32[16] private EMPTY_VM_PUBLIC_KEY = [bytes32(0)];
  bytes32[5] private EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID = [bytes32(0)];
  address private constant EMPTY_VM_THIS_BC_ADDRESS = address(0);
  bytes1 private constant EMPTY_VM_RELATIONSHIPS = bytes1(0);
  uint256 private constant EMPTY_VM_EXPIRATION = 0;
  bytes32[2] private DEFAULT_VM_TYPE = [bytes32("EcdsaSecp256k1VerificationKey20"), bytes32("19")];
  bytes32[16] private DEFAULT_VM_PUBLIC_KEY = [
    bytes32("0x04a2b4f3b4"),
    bytes32("0a2b4f3b4"),
    bytes32("0b2b4f3b4")
  ];
  // "eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb"
  bytes32[5] private DEFAULT_VM_BLOCKCHAIN_ACCOUNT_ID = [
    bytes32("eid155:1:0xab16a96d359ec26a11e2c"),
    bytes32("2b3d8f8b8942d5bfcdb")
  ];
  address private constant DEFAULT_VM_THIS_BC_ADDRESS = address(666);
  bytes1 private constant DEFAULT_VM_RELATIONSHIPS = bytes1(0x01);
  bytes32[10] VM_ID = [bytes32("vm-create-test"), bytes32("vm-validate-test")];
  // Variables
  uint256 DEFAULT_VM_EXPIRATION;
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
  function test_should_createNewVM() public {
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
    VerificationMethod memory verificationMethod = didManager.getVM(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      VM_ID[0],
      uint8(0)
    );
    _assertEmptyVm(verificationMethod);
    verificationMethod = didManager.getVM(
      didData.method0,
      didData.method1,
      didData.method2,
      didData.id,
      bytes32(0),
      uint8(2)
    );
    _assertEmptyVm(verificationMethod);
    //* 🎬 Act ⬇
    // Add new service
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
    verificationMethod = didManager.getVM(
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
        command.thisBCAddress,
        command.relationships,
        command.expiration
      )
    );
    // -- final vm by ID
    verificationMethod = didManager.getVM(
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
        command.thisBCAddress,
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

  // // UPDATE SERVICE
  // function test_should_updateService() public {
  //   //* 🗂️ Arrange ⬇
  //   IDidManager didManager = _getNextInitDidManager();
  //   DidInfo memory didData = userDidInfo;
  //   startHoax(user, DEFAULT_USER_BALANCE);
  //   // Add new service
  //   (
  //     PerformedAction performedAction,
  //     bytes32 ServiceUpdated_didIdHash,
  //     bytes32 ServiceUpdated_id,
  //     bytes32 ServiceUpdated_serviceIdHash,
  //     bytes32 ServiceUpdated_positionHash
  //   ) = _updateService(
  //       didManager,
  //       didData.method0,
  //       didData.method1,
  //       didData.method2,
  //       didData.id,
  //       DEFAULT_VM_ID,
  //       didData.id,
  //       DEFAULT_SERVICE_ID,
  //       DEFAULT_SERVICE_TYPE,
  //       DEFAULT_SERVICE_ENDPOINT
  //     );
  //   // Check previous state
  //   assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
  //   uint256 length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didData.id
  //   );
  //   assertEq(length, 1);
  //   //* 🎬 Act ⬇
  //   // Update service
  //   (
  //     performedAction,
  //     ServiceUpdated_didIdHash,
  //     ServiceUpdated_id,
  //     ServiceUpdated_serviceIdHash,
  //     ServiceUpdated_positionHash
  //   ) = _updateService(
  //     didManager,
  //     didData.method0,
  //     didData.method1,
  //     didData.method2,
  //     didData.id,
  //     DEFAULT_VM_ID,
  //     didData.id,
  //     DEFAULT_SERVICE_ID,
  //     UPDATE_SERVICE_TYPE,
  //     UPDATE_SERVICE_ENDPOINT
  //   );
  //   //* ☑️ Assert ⬇
  //   // Final length
  //   length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didData.id
  //   );
  //   bytes32 serviceDidHash = keccak256(abi.encodePacked(didData.idHash, SERVICE_NAMESPACE));
  //   bytes32 expectedServiceIdHash = keccak256(abi.encodePacked(serviceDidHash, DEFAULT_SERVICE_ID));
  //   bytes32 expectedPositionHash = keccak256(abi.encodePacked(serviceDidHash, uint8(0)));
  //   // Check final state
  //   assertEq(length, 1);
  //   // -- final "first service"
  //   Service memory service = didManager.getService(
  //     didData.method0,
  //     didData.method1,
  //     didData.method2,
  //     didData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, DEFAULT_SERVICE_ID);
  //   assertEq(service.type_[0], UPDATE_SERVICE_TYPE[0]);
  //   assertEq(service.type_[1], UPDATE_SERVICE_TYPE[1]);
  //   assertEq(service.type_[2], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], UPDATE_SERVICE_ENDPOINT[0]);
  //   assertEq(service.serviceEndpoint[1], UPDATE_SERVICE_ENDPOINT[1]);
  //   assertEq(service.serviceEndpoint[2], bytes32(0));
  //   // -- final service by ID
  //   service = didManager.getService(
  //     didData.method0,
  //     didData.method1,
  //     didData.method2,
  //     didData.id,
  //     DEFAULT_SERVICE_ID,
  //     uint8(0)
  //   );
  //   assertEq(service.id, DEFAULT_SERVICE_ID);
  //   assertEq(service.type_[0], UPDATE_SERVICE_TYPE[0]);
  //   assertEq(service.type_[1], UPDATE_SERVICE_TYPE[1]);
  //   assertEq(service.type_[2], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], UPDATE_SERVICE_ENDPOINT[0]);
  //   assertEq(service.serviceEndpoint[1], UPDATE_SERVICE_ENDPOINT[1]);
  //   assertEq(service.serviceEndpoint[2], bytes32(0));
  //   // Check Events
  //   // ServiceUpdated(
  //   //   bytes32 indexed didIdHash,
  //   //   bytes32 indexed id,
  //   //   bytes32 indexed serviceIdHash,
  //   //   bytes32 positionHash
  //   // );
  //   assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
  //   assertEq(ServiceUpdated_didIdHash, didData.idHash);
  //   assertEq(ServiceUpdated_id, DEFAULT_SERVICE_ID);
  //   assertEq(ServiceUpdated_serviceIdHash, expectedServiceIdHash);
  //   assertEq(ServiceUpdated_positionHash, expectedPositionHash);
  //   // end
  //   vm.stopPrank();
  // }

  // function test_shouldNot_updateService_notInControl() public {
  //   //* 🗂️ Arrange ⬇
  //   IDidManager didManager = _getNextInitDidManager();
  //   DidInfo memory didUserData = userDidInfo;
  //   DidInfo memory didOtherData = otherUserDidInfo;
  //   startHoax(otherUser, DEFAULT_USER_BALANCE);
  //   // Check previous state
  //   uint256 length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   assertEq(length, 0);
  //   Service memory service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   //* 🎬 Act ⬇
  //   vm.expectRevert(bytes(REVERT_NOT_CONTROLLER));
  //   // Add new service from other user
  //   didManager.updateService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didOtherData.id,
  //     DEFAULT_VM_ID,
  //     didUserData.id,
  //     DEFAULT_SERVICE_ID,
  //     DEFAULT_SERVICE_TYPE,
  //     DEFAULT_SERVICE_ENDPOINT
  //   );
  //   //* ☑️ Assert ⬇
  //   // Final length
  //   length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   // Check final state
  //   assertEq(length, 0);
  //   // -- final "first service"
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // -- final service by ID
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     DEFAULT_SERVICE_ID,
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // end
  //   vm.stopPrank();
  // }

  // // function test_shouldNot_updateService_emptyDidHash() public //! Not possible to test

  // function test_shouldNot_updateService_emptyId() public {
  //   //* 🗂️ Arrange ⬇
  //   IDidManager didManager = _getNextInitDidManager();
  //   DidInfo memory didUserData = userDidInfo;
  //   startHoax(user, DEFAULT_USER_BALANCE);
  //   // Check previous state
  //   uint256 length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   assertEq(length, 0);
  //   Service memory service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   //* 🎬 Act ⬇
  //   vm.expectRevert(bytes(REVERT_EMPTY_ID));
  //   // Add new service from other user
  //   didManager.updateService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     DEFAULT_VM_ID,
  //     didUserData.id,
  //     bytes32(0), //! <---- empty ID
  //     DEFAULT_SERVICE_TYPE,
  //     DEFAULT_SERVICE_ENDPOINT
  //   );
  //   //* ☑️ Assert ⬇
  //   // Final length
  //   length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   // Check final state
  //   assertEq(length, 0);
  //   // -- final "first service"
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // -- final service by ID
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // end
  //   vm.stopPrank();
  // }

  // function test_shouldNot_updateService_emptyType() public {
  //   //* 🗂️ Arrange ⬇
  //   IDidManager didManager = _getNextInitDidManager();
  //   DidInfo memory didUserData = userDidInfo;
  //   startHoax(user, DEFAULT_USER_BALANCE);
  //   // Check previous state
  //   uint256 length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   assertEq(length, 0);
  //   Service memory service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   //* 🎬 Act ⬇
  //   vm.expectRevert(bytes(REVERT_EMPTY_TYPE));
  //   // Add new service from other user
  //   didManager.updateService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     DEFAULT_VM_ID,
  //     didUserData.id,
  //     DEFAULT_SERVICE_ID,
  //     EMPTY_SERVICE_TYPE, //! <---- empty type
  //     DEFAULT_SERVICE_ENDPOINT
  //   );
  //   //* ☑️ Assert ⬇
  //   // Final length
  //   length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   // Check final state
  //   assertEq(length, 0);
  //   // -- final "first service"
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // -- final service by ID
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     DEFAULT_SERVICE_ID,
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // end
  //   vm.stopPrank();
  // }

  // function test_shouldNot_updateService_emptyEndpoint() public {
  //   //* 🗂️ Arrange ⬇
  //   IDidManager didManager = _getNextInitDidManager();
  //   DidInfo memory didUserData = userDidInfo;
  //   startHoax(user, DEFAULT_USER_BALANCE);
  //   // Check previous state
  //   uint256 length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   assertEq(length, 0);
  //   Service memory service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   //* 🎬 Act ⬇
  //   vm.expectRevert(bytes(REVERT_EMPTY_ENDPOINT));
  //   // Add new service from other user
  //   didManager.updateService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     DEFAULT_VM_ID,
  //     didUserData.id,
  //     DEFAULT_SERVICE_ID,
  //     DEFAULT_SERVICE_TYPE,
  //     EMPTY_SERVICE_ENDPOINT //! <---- empty endpoint
  //   );
  //   //* ☑️ Assert ⬇
  //   // Final length
  //   length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didUserData.id
  //   );
  //   // Check final state
  //   assertEq(length, 0);
  //   // -- final "first service"
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // -- final service by ID
  //   service = didManager.getService(
  //     didUserData.method0,
  //     didUserData.method1,
  //     didUserData.method2,
  //     didUserData.id,
  //     DEFAULT_SERVICE_ID,
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // end
  //   vm.stopPrank();
  // }

  // // REMOVE SERVICE
  // function test_should_removeService() public {
  //   //* 🗂️ Arrange ⬇
  //   IDidManager didManager = _getNextInitDidManager();
  //   DidInfo memory didData = userDidInfo;
  //   startHoax(user, DEFAULT_USER_BALANCE);
  //   // Add new service
  //   (
  //     PerformedAction performedAction,
  //     bytes32 ServiceUpdated_didIdHash,
  //     bytes32 ServiceUpdated_id,
  //     bytes32 ServiceUpdated_serviceIdHash,
  //     bytes32 ServiceUpdated_positionHash
  //   ) = _updateService(
  //       didManager,
  //       didData.method0,
  //       didData.method1,
  //       didData.method2,
  //       didData.id,
  //       DEFAULT_VM_ID,
  //       didData.id,
  //       DEFAULT_SERVICE_ID,
  //       DEFAULT_SERVICE_TYPE,
  //       DEFAULT_SERVICE_ENDPOINT
  //     );
  //   // Check previous state
  //   assertTrue(performedAction == PerformedAction.CREATEorUPDATE);
  //   uint256 length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didData.id
  //   );
  //   assertEq(length, 1);
  //   //* 🎬 Act ⬇
  //   // Delete service
  //   (
  //     performedAction,
  //     ServiceUpdated_didIdHash,
  //     ServiceUpdated_id,
  //     ServiceUpdated_serviceIdHash,
  //     ServiceUpdated_positionHash
  //   ) = _updateService(
  //     didManager,
  //     didData.method0,
  //     didData.method1,
  //     didData.method2,
  //     didData.id,
  //     DEFAULT_VM_ID,
  //     didData.id,
  //     DEFAULT_SERVICE_ID,
  //     EMPTY_SERVICE_TYPE,
  //     EMPTY_SERVICE_ENDPOINT
  //   );
  //   //* ☑️ Assert ⬇
  //   // Final length
  //   length = didManager.getServiceListLength(
  //     DEFAULT_DID_METHOD0,
  //     DEFAULT_DID_METHOD1,
  //     DEFAULT_DID_METHOD2,
  //     didData.id
  //   );
  //   bytes32 serviceDidHash = keccak256(abi.encodePacked(didData.idHash, SERVICE_NAMESPACE));
  //   bytes32 expectedServiceIdHash = keccak256(abi.encodePacked(serviceDidHash, DEFAULT_SERVICE_ID));
  //   bytes32 expectedPositionHash = 0;
  //   // Check final state
  //   assertEq(length, 0);
  //   // -- final "first service"
  //   Service memory service = didManager.getService(
  //     didData.method0,
  //     didData.method1,
  //     didData.method2,
  //     didData.id,
  //     bytes32(0),
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // -- final service by ID
  //   service = didManager.getService(
  //     didData.method0,
  //     didData.method1,
  //     didData.method2,
  //     didData.id,
  //     DEFAULT_SERVICE_ID,
  //     uint8(0)
  //   );
  //   assertEq(service.id, bytes32(0));
  //   assertEq(service.type_[0], bytes32(0));
  //   assertEq(service.serviceEndpoint[0], bytes32(0));
  //   // Check Events
  //   // ServiceUpdated(
  //   //   bytes32 indexed didIdHash,
  //   //   bytes32 indexed id,
  //   //   bytes32 indexed serviceIdHash,
  //   //   bytes32 positionHash
  //   // );
  //   assertTrue(performedAction == PerformedAction.DELETE);
  //   assertEq(ServiceUpdated_didIdHash, didData.idHash);
  //   assertEq(ServiceUpdated_id, DEFAULT_SERVICE_ID);
  //   assertEq(ServiceUpdated_serviceIdHash, expectedServiceIdHash);
  //   assertEq(ServiceUpdated_positionHash, expectedPositionHash);
  //   // end
  //   vm.stopPrank();
  // }

  // * Internal functions

  /**
   * @dev Updates a service.
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
    didManager.createVM(command);
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
    assertEq(verificationMethod.thisBCAddress, address(0));
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
    assertEq(vmToCheck.thisBCAddress, expectedVM.thisBCAddress);
    assertEq(vmToCheck.relationships, expectedVM.relationships);
    assertEq(vmToCheck.expiration, expectedVM.expiration);
  }
}
