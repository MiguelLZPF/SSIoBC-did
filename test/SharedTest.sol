// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerScript, DeployCommand } from "@script/DidManager.s.sol";
import { IDidManager, CreateVmCommand as DidCreateVmCommand } from "@src/interfaces/IDidManager.sol";
import { SERVICE_MAX_LENGTH_LIST, SERVICE_MAX_LENGTH } from "@src/ServiceStorage.sol";

struct DidInfo {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 id;
  bytes32 idHash;
  address creator;
}

struct CreateVmResultTest {
  bytes32 VmCreated_didIdHash;
  bytes32 VmCreated_id;
  bytes32 VmCreated_idHash;
  bytes32 VmCreated_positionHash;
}

abstract contract SharedTest is Test {
  // * Shared Constants
  // General
  uint256 constant DEFAULT_USER_BALANCE = 100 ether;
  uint256 EMPTY_EXPIRATION = 0;
  // DID
  bytes32 constant EMPTY_DID_METHOD = bytes32(0);
  bytes32 constant DEFAULT_DID_METHOD0 = bytes32("lzpf");
  bytes32 constant DEFAULT_DID_METHOD1 = bytes32("main");
  bytes32 constant DEFAULT_DID_METHOD2 = EMPTY_DID_METHOD;
  bytes32 constant EMPTY_DID_ID = bytes32(0);
  bytes32 constant EMPTY_RANDOM = bytes32(0);
  // VM
  bytes32 constant EMPTY_VM_ID = bytes32(0);
  bytes32 constant DEFAULT_VM_ID = bytes32("vm-0");
  bytes32[2] EMPTY_VM_TYPE = [bytes32(0)];
  bytes32[2] DEFAULT_VM_TYPE = [bytes32("EcdsaSecp256k1VerificationKey20"), bytes32("19")];
  bytes32[16] EMPTY_VM_PUBLIC_KEY = [bytes32(0)];
  bytes32[16] DEFAULT_VM_PUBLIC_KEY = [
    bytes32("FD756c746962617365206973206177"),
    bytes32("65736F6d6521205C6f2F"),
    bytes32("65736F6d6521205C6f2F")
  ];
  bytes32[5] EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID = [bytes32(0)];
  // "eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb"
  bytes32[5] DEFAULT_VM_BLOCKCHAIN_ACCOUNT_ID = [
    bytes32("eid155:1:0xab16a96d359ec26a11e2c"),
    bytes32("2b3d8f8b8942d5bfcdb")
  ];
  address constant EMPTY_VM_ETHEREUM_ADDRESS = address(0);
  address constant DEFAULT_VM_ETHEREUM_ADDRESS =
    address(0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb);
  uint256 constant EMPTY_VM_EXPIRATION = 0;
  // Service
  bytes32 constant DEFAULT_SERVICE_ID = bytes32("linked-domain");
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] DEFAULT_SERVICE_TYPE = [
    [bytes32("LinkedDomains")]
  ];
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] internal DEFAULT_SERVICE_ENDPOINT = [
    [bytes32("https://bar.example.com")]
  ];
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] SERVICE_TYPE_SC = [
    [bytes32("VerifiableCredentialService")],
    [bytes32("SmartContractEndpoint")]
  ];
  bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] internal SERVICE_ENDPOINT_SC = [
    [bytes32("0xe7f1725E7734CE288F8367e1Bb143E"), bytes32("90bb3F0512")]
  ];
  // -- relation
  bytes1 constant VM_RELATIONSHIPS_NONE = bytes1(0x00);
  bytes1 constant VM_RELATIONSHIPS_AUTHENTICATION = bytes1(0x01);
  bytes1 constant VM_RELATIONSHIPS_ASSERTION_METHOD = bytes1(0x02);
  bytes1 constant VM_RELATIONSHIPS_KEY_AGREEMENT = bytes1(0x04);
  bytes1 constant VM_RELATIONSHIPS_CAPABILITY_INVOCATION = bytes1(0x08);
  bytes1 constant VM_RELATIONSHIPS_CAPABILITY_DELEGATION = bytes1(0x10);
  bytes1 constant VM_RELATIONSHIPS_ALL = bytes1(0x1F);
  bytes1 internal constant DEFAULT_VM_RELATIONSHIPS = VM_RELATIONSHIPS_AUTHENTICATION;

  address constant EMPTY_SENDER = address(0);
  // * Shared Variables
  // -- Contracts
  IDidManager didManager;

  function _deployNewDidManager() internal returns (IDidManager) {
    (didManager, ) = new DidManagerScript().deploy(
      DeployCommand({ storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) }) }),
      false
    );
    return didManager;
  }

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

  /**
   * @dev Creates a new verification method.
   */
  function _createVm(
    DidCreateVmCommand memory command
  ) internal returns (CreateVmResultTest memory result) {
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
    result.VmCreated_didIdHash = entries[0].topics[1];
    result.VmCreated_id = entries[0].topics[2];
    result.VmCreated_idHash = entries[0].topics[3];
    result.VmCreated_positionHash = bytes32(entries[0].data);
  }

  function _calculateDidHash(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(method0, method1, method2, random));
  }
}
