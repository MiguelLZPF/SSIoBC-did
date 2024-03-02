// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager } from "@src/DidManager.sol";

struct CreateExampleDidParams {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 random;
  bytes32 vmId;
}

contract DidManagerTest is Test {
  // Constants
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  bytes32 private constant DEFAULT_VM_ID = bytes32("vm-0");
  CreateExampleDidParams DEFAULT_CREATE_EXAMPLE_DID_PARAMS =
    CreateExampleDidParams(
      bytes32("my-method"),
      bytes32(0),
      bytes32(0),
      keccak256("randomString"),
      bytes32("verifMethod_01")
    );
  // Variables
  IDidManager public didManager;
  address admin = DEFAULT_SENDER;
  address payable[] users = [payable(address(10)), payable(address(11)), payable(address(12))];

  function setUp() public {
    Deployment memory deployment;
    // Transfer some ether to users
    for (uint i = 0; i < users.length; i++) {
      vm.deal(users[i], DEFAULT_USER_BALANCE);
    }
    // Deploy the contract
    (didManager, deployment) = new DidManagerScript().deploy(
      DeployCommand({ storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) }) })
    );
    // Check the initial state
  }

  function test_shouldCreateDefaultDid() public {
    vm.startPrank(users[0]);
    // // Initial state check

    // Event recording
    vm.recordLogs();
    // Create DID
    didManager.createDid(
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(uint256(uint160(msg.sender))),
      bytes32(DEFAULT_VM_ID)
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    bytes32 VmCreated_didIdHash = entries[0].topics[1];
    bytes32 VmCreated_id = entries[0].topics[2];
    assertGt(uint256(VmCreated_didIdHash), uint256(100));
    assertEq(VmCreated_id, DEFAULT_VM_ID);
    // VmValidated(bytes32 indexed id);
    bytes32 VmValidated_id = entries[1].topics[1];
    assertEq(VmValidated_id, bytes32(DEFAULT_VM_ID));
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed idHash, address indexed creator);
    bytes32 DidCreated_id = entries[2].topics[1];
    address DidCreated_creator = address(uint160(uint256((entries[2].topics[2]))));
    assertGt(uint256(DidCreated_id), uint256(100));
    assertEq(DidCreated_creator, users[0]);
    assertEq(VmCreated_didIdHash, DidCreated_id);
    // // Final state check
  }

  function test_shouldCreateDid() public {
    vm.startPrank(users[0]);
    // // Initial state check

    // Event recording
    vm.recordLogs();
    // Create DID
    didManager.createDid(
      DEFAULT_CREATE_EXAMPLE_DID_PARAMS.method0,
      DEFAULT_CREATE_EXAMPLE_DID_PARAMS.method1,
      DEFAULT_CREATE_EXAMPLE_DID_PARAMS.method2,
      DEFAULT_CREATE_EXAMPLE_DID_PARAMS.random,
      DEFAULT_CREATE_EXAMPLE_DID_PARAMS.vmId
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    // VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed vmIdHash, bytes32 positionHash);
    bytes32 VmCreated_didIdHash = entries[0].topics[1];
    bytes32 VmCreated_id = entries[0].topics[2];
    assertGt(uint256(VmCreated_didIdHash), uint256(100));
    assertEq(VmCreated_id, DEFAULT_CREATE_EXAMPLE_DID_PARAMS.vmId);
    // VmValidated(bytes32 indexed id);
    bytes32 VmValidated_id = entries[1].topics[1];
    assertEq(VmValidated_id, bytes32(DEFAULT_CREATE_EXAMPLE_DID_PARAMS.vmId));
    assertEq(VmCreated_id, VmValidated_id);
    // DidCreated(bytes32 indexed idHash, address indexed creator);
    bytes32 DidCreated_id = entries[2].topics[1];
    address DidCreated_creator = address(uint160(uint256((entries[2].topics[2]))));
    assertGt(uint256(DidCreated_id), uint256(100));
    assertEq(DidCreated_creator, users[0]);
    assertEq(VmCreated_didIdHash, DidCreated_id);
    // // Final state check
  }
}
