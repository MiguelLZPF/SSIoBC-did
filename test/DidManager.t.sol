// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager } from "@src/DidManager.sol";

contract DidManagerTest is Test {
  // Constants
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
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
      bytes32("vm-0")
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    bytes32 id = entries[0].topics[1];
    address logic = address(uint160(uint256((entries[0].topics[2]))));
    assertGt(uint256(id), uint256(100));
    assertEq(logic, users[0]);
    // // Final state check
  }

  function test_shouldCreateDid() public {
    vm.startPrank(users[0]);
    // // Initial state check

    // Event recording
    vm.recordLogs();
    // Create DID
    didManager.createDid(
      bytes32("MyMethod"),
      bytes32(0),
      bytes32(0),
      keccak256("randomString"),
      bytes32("verifMethod_01")
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the event values
    bytes32 id = entries[0].topics[1];
    address logic = address(uint160(uint256((entries[0].topics[2]))));
    assertGt(uint256(id), uint256(100));
    assertEq(logic, users[0]);
    // // Final state check
  }
}
