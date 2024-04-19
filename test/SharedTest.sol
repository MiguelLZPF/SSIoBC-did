// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager } from "@src/interfaces/IDidManager.sol";

struct DidInfo {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 id;
  bytes32 idHash;
  address creator;
}

abstract contract SharedTest is Test {
  // * Shared Constants
  uint256 EMPTY_EXPIRATION = 0;
  // DID
  bytes32 constant EMPTY_DID_METHOD = bytes32(0);
  bytes32 constant DEFAULT_DID_METHOD0 = bytes32("lzpf");
  bytes32 constant DEFAULT_DID_METHOD1 = bytes32("main");
  bytes32 constant DEFAULT_DID_METHOD2 = EMPTY_DID_METHOD;
  // VM
  bytes32 constant EMPTY_VM_ID = bytes32(0);
  bytes32 constant DEFAULT_VM_ID = bytes32("vm-0");
  // -- relation
  bytes1 constant VM_RELATIONSHIPS_NONE = bytes1(0x00);
  bytes1 constant VM_RELATIONSHIPS_AUTHENTICATION = bytes1(0x01);
  bytes1 constant VM_RELATIONSHIPS_ASSERTION_METHOD = bytes1(0x02);
  bytes1 constant VM_RELATIONSHIPS_KEY_AGREEMENT = bytes1(0x04);
  bytes1 constant VM_RELATIONSHIPS_CAPABILITY_INVOCATION = bytes1(0x08);
  bytes1 constant VM_RELATIONSHIPS_CAPABILITY_DELEGATION = bytes1(0x10);

  function _deployNewDidManager() internal returns (IDidManager didManager) {
    (didManager, ) = new DidManagerScript().deploy(
      DeployCommand({ storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) }) }),
      false
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
}
