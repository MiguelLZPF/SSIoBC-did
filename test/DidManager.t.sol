// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, UpdateControllerCommand, VerificationMethod } from "@src/interfaces/IDidManager.sol";
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

contract DidManagerTest is Test {
  //* Constants
  // General
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  // Specific
  bytes1 private constant VM_RELATIONSHIPS_NONE = bytes1(0x00);
  bytes1 private constant VM_RELATIONSHIPS_AUTHENTICATION = bytes1(0x01);
  bytes1 private constant VM_RELATIONSHIPS_ASSERTION_METHOD = bytes1(0x02);
  bytes1 private constant VM_RELATIONSHIPS_KEY_AGREEMENT = bytes1(0x04);
  bytes1 private constant VM_RELATIONSHIPS_CAPABILITY_INVOCATION = bytes1(0x08);
  bytes1 private constant VM_RELATIONSHIPS_CAPABILITY_DELEGATION = bytes1(0x10);
  bytes32 private constant DEFAULT_DID_METHOD0 = bytes32("lzpf");
  bytes32 private constant DEFAULT_DID_METHOD1 = bytes32("main");
  bytes32 private constant DEFAULT_DID_METHOD2 = bytes32(0);
  bytes32 private constant DEFAULT_VM_ID = bytes32("vm-0");
  CreateExampleDidParams CREATE_EXAMPLE_DID_PARAMS =
    CreateExampleDidParams(
      bytes32("my-method0"),
      bytes32("my-method1"),
      bytes32("my-method2"),
      keccak256("randomString"),
      bytes32("verifMethod_01")
    );
  // Variables
  IDidManager public didManager;
  address admin = DEFAULT_SENDER;
  address payable[] users = [payable(address(10)), payable(address(11)), payable(address(12))];

  function setUp() public {
    console.logBytes32(DEFAULT_DID_METHOD1);
    Deployment memory deployment;
    // Transfer some ether to users
    for (uint i = 0; i < users.length; i++) {
      vm.deal(users[i], DEFAULT_USER_BALANCE);
    }
    // Deploy the contract
    (didManager, deployment) = new DidManagerScript().deploy(
      DeployCommand({ storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) }) })
    );
    // Check the initial state (nothing to check)
  }

  //* TESTS
  function test_should_createDefaultDid() public {
    vm.startPrank(users[0]);
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
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(uint256(uint160(msg.sender))),
        bytes32(0)
      );
    //* Check Events
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    assertGt(uint256(VmCreated_didIdHash), uint256(100));
    assertEq(VmCreated_id, DEFAULT_VM_ID);
    // VmValidated(bytes32 indexed id);
    assertEq(VmValidated_id, bytes32(DEFAULT_VM_ID));
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertGt(uint256(DidCreated_id), uint256(100));
    assertGt(uint256(DidCreated_idHash), uint256(100));
    assertEq(
      DidCreated_idHash,
      keccak256(
        abi.encodePacked(
          DEFAULT_DID_METHOD0,
          DEFAULT_DID_METHOD1,
          DEFAULT_DID_METHOD2,
          DidCreated_id
        )
      )
    );
    assertEq(DidCreated_creator, users[0]);
    assertEq(VmCreated_didIdHash, DidCreated_idHash);
    //* Final state check
    VerificationMethod memory verificationMethod = didManager.getVM(
      DEFAULT_DID_METHOD0,
      DEFAULT_DID_METHOD1,
      DEFAULT_DID_METHOD2,
      DidCreated_id,
      DEFAULT_VM_ID
    );
    assertEq(verificationMethod.id, DEFAULT_VM_ID);
    assertEq(verificationMethod.thisBCAddress, users[0]);
    assertEq(verificationMethod.relationships, VM_RELATIONSHIPS_AUTHENTICATION);
    assertGt(verificationMethod.expiration, block.timestamp);
    // end
    vm.stopPrank();
  }

  function test_should_createDid() public {
    vm.startPrank(users[0]);
    // TODO // Initial state check

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
        CREATE_EXAMPLE_DID_PARAMS.method0,
        CREATE_EXAMPLE_DID_PARAMS.method1,
        CREATE_EXAMPLE_DID_PARAMS.method2,
        CREATE_EXAMPLE_DID_PARAMS.random,
        CREATE_EXAMPLE_DID_PARAMS.vmId
      );
    //* Check Events
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    assertGt(uint256(VmCreated_didIdHash), uint256(100));
    assertEq(VmCreated_id, CREATE_EXAMPLE_DID_PARAMS.vmId);
    // VmValidated(bytes32 indexed id);
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);
    assertGt(uint256(DidCreated_id), uint256(100));
    assertGt(uint256(DidCreated_idHash), uint256(100));
    assertEq(
      DidCreated_idHash,
      keccak256(
        abi.encodePacked(
          CREATE_EXAMPLE_DID_PARAMS.method0,
          CREATE_EXAMPLE_DID_PARAMS.method1,
          CREATE_EXAMPLE_DID_PARAMS.method2,
          DidCreated_id
        )
      )
    );
    assertEq(DidCreated_creator, users[0]);
    assertEq(VmCreated_didIdHash, DidCreated_idHash);
    //* Final state check
    VerificationMethod memory verificationMethod = didManager.getVM(
      CREATE_EXAMPLE_DID_PARAMS.method0,
      CREATE_EXAMPLE_DID_PARAMS.method1,
      CREATE_EXAMPLE_DID_PARAMS.method2,
      DidCreated_id,
      CREATE_EXAMPLE_DID_PARAMS.vmId
    );
    assertEq(verificationMethod.id, CREATE_EXAMPLE_DID_PARAMS.vmId);
    assertEq(verificationMethod.thisBCAddress, users[0]);
    assertEq(verificationMethod.relationships, VM_RELATIONSHIPS_AUTHENTICATION);
    assertGt(verificationMethod.expiration, block.timestamp);
    // end
    vm.stopPrank();
  }

  function test_should_updateSameController() public {
    vm.startPrank(users[0]);
    (DidInfo memory defaultDid, , , , , , ) = _createDid(
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(uint256(uint160(msg.sender))),
      bytes32(0)
    );
    // TODO // Initial state check

    UpdateControllerCommand memory updateControllerCommand = UpdateControllerCommand(
      defaultDid.method0,
      defaultDid.method1,
      defaultDid.method2,
      defaultDid.id,
      DEFAULT_VM_ID,
      defaultDid.method0,
      defaultDid.method1,
      defaultDid.method2,
      defaultDid.id,
      defaultDid.method0,
      defaultDid.method1,
      defaultDid.method2,
      defaultDid.id,
      DEFAULT_VM_ID,
      0
    );
    //* Update controller
    (
      bytes32 ControllerUpdated_fromDidHash,
      bytes32 ControllerUpdated_toDidHash,
      bytes32 ControllerUpdated_controllerDidOrDidVmIdHash
    ) = _updateController(updateControllerCommand);
    //* Check Events
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, bytes32 indexed controllerDidOrDidVmIdHash, uint8 controllerPosition)
    assertGt(uint256(ControllerUpdated_fromDidHash), uint256(100));
    assertGt(uint256(ControllerUpdated_toDidHash), uint256(100));
    assertGt(uint256(ControllerUpdated_controllerDidOrDidVmIdHash), uint256(100));
    assertEq(ControllerUpdated_fromDidHash, defaultDid.idHash);
    assertEq(ControllerUpdated_toDidHash, defaultDid.idHash);
    assertEq(
      ControllerUpdated_controllerDidOrDidVmIdHash,
      keccak256(abi.encodePacked(defaultDid.idHash, DEFAULT_VM_ID))
    );
    vm.stopPrank();
    // TODO // Final state check
  }

  // * Internal functions

  function _createDid(
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
    // Store data for future tests
    didInfo = DidInfo({
      method0: DEFAULT_DID_METHOD0,
      method1: DEFAULT_DID_METHOD1,
      method2: DEFAULT_DID_METHOD2,
      id: DidCreated_id,
      idHash: DidCreated_idHash,
      creator: DidCreated_creator
    });
  }

  function _updateController(
    UpdateControllerCommand memory command
  )
    internal
    returns (
      bytes32 ControllerUpdated_fromDidHash,
      bytes32 ControllerUpdated_toDidHash,
      bytes32 ControllerUpdated_controllerDidOrDidVmIdHash
    )
  {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.updateController(command);
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // ControllerUpdated(bytes32 indexed fromDidHash, bytes32 indexed toDidHash, bytes32 indexed controllerDidOrDidVmIdHash, uint8 controllerPosition)
    ControllerUpdated_fromDidHash = entries[0].topics[1];
    ControllerUpdated_toDidHash = entries[0].topics[2];
    ControllerUpdated_controllerDidOrDidVmIdHash = entries[0].topics[3];
  }
}
