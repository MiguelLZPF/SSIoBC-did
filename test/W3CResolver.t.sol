// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { W3CResolverScript, DeployCommand } from "@script/W3CResolver.s.sol";
import { SharedTest, DidInfo, CreateVmResultTest } from "@test/SharedTest.sol";
import { PerformedAction, Service, ServiceUpdateCommandTest, ServiceUpdateResultTest } from "@test/ServiceStorage.t.sol";
import { IDidManager, VerificationMethod, Controller, CreateVmCommand, EXPIRATION, CONTROLLERS_MAX_LENGTH, SERVICE_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { IW3CResolver, W3CDidDocument, W3CVerificationMethod, W3CService, W3CDidInput } from "@src/interfaces/IW3CResolver.sol";

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
  // Specific
  string[] private DEFAULT_CONTEXT = ["https://www.w3.org/ns/did/v1"];
  bytes32 private constant RANDOM_CREATE_DEFAULT = bytes32("This is a random value");
  bytes32 private constant RANDOM_CREATE_CUSTOM = bytes32("This is another random value");
  bytes32 private constant RANDOM_AUTHENTICATE = bytes32("Random value authenticate");
  bytes32 private constant RANDOM_RELATIONSHIP = bytes32("Random value relationship");
  bytes32 private constant DID_METHOD_0_CUSTOM = bytes32("method0_custom");
  bytes32 private constant DID_METHOD_1_CUSTOM = bytes32("method1_custom");
  bytes32 private constant DID_METHOD_2_CUSTOM = bytes32("method2_custom");
  bytes32 private constant VM_ID_CUSTOM = bytes32("vm_custom");
  bytes32 private constant VM_ID_CUSTOM_2 = bytes32("vm_custom_2");
  bytes32 private constant DEFAULT_SERVICE_ID = bytes32("linked-domain");
  bytes32[SERVICE_MAX_LENGTH] private DEFAULT_SERVICE_TYPE = [bytes32("LinkedDomains")];
  bytes32[SERVICE_MAX_LENGTH] private DEFAULT_SERVICE_ENDPOINT = [
    bytes32("https://bar.example.com")
  ];
  // Variables
  uint256 private DEFAULT_VM_EXPIRATION;
  // -- users
  address admin = DEFAULT_SENDER;
  address user = payable(address(10));
  address otherUser = payable(address(11));
  address user1 = payable(address(12));
  // -- contracts
  uint256 lastDidManagerUsed;
  IW3CResolver w3cResolver;

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
    w3cResolver = _deployNewW3cResolver(didManager);
    // Label contracts
    vm.label(address(didManager), "blankDidManager");
  }

  //* TESTS
  // Verification Method
  function test_should_resolveVm_withDefaultParams() public {
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
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Check final state
    W3CVerificationMethod memory w3cVm = w3cResolver.resolveVm(
      W3CDidInput({
        method0: DEFAULT_DID_METHOD0,
        method1: DEFAULT_DID_METHOD1,
        method2: DEFAULT_DID_METHOD2,
        id: didInfo.id,
        fragment: EMPTY_VM_ID
      }),
      DEFAULT_VM_ID
    );
    //* ☑️ Assert ⬇
    assertEq(
      keccak256(abi.encodePacked(w3cVm.id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_VM_ID)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.type_)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_VM_TYPE)))))
    );
    // end
    vm.stopPrank();
  }

  // Service
  function test_should_resolveService_withDefaultParams() public {
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
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Add a new Service
    ServiceUpdateResultTest memory result = _updateService(
      ServiceUpdateCommandTest({
        method0: didInfo.method0,
        method1: didInfo.method1,
        method2: didInfo.method2,
        senderId: didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    //* 🎬 Act ⬇
    // Check final state
    W3CService memory w3cService = w3cResolver.resolveService(
      W3CDidInput({
        method0: DEFAULT_DID_METHOD0,
        method1: DEFAULT_DID_METHOD1,
        method2: DEFAULT_DID_METHOD2,
        id: didInfo.id,
        fragment: EMPTY_VM_ID
      }),
      DEFAULT_SERVICE_ID
    );
    //* ☑️ Assert ⬇
    assertEq(
      keccak256(abi.encodePacked(w3cService.id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_SERVICE_ID)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cService.id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(result.ServiceUpdated_id)))))
    );
    // end
    vm.stopPrank();
  }

  // DID Document
  // It creates a DID with multiple VMs and Services and resolves it
  function test_should_resolveDid_withMultVmNServices() public {
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
    // Create DID
    (DidInfo memory didInfo, , , , , , ) = _createDid(
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      EMPTY_DID_METHOD,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Add a new VM with all methods
    // Add new Verification Method
    CreateVmResultTest memory createVmResult = _createVm(
      CreateVmCommand({
        method0: didInfo.method0,
        method1: didInfo.method1,
        method2: didInfo.method2,
        senderId: didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        id: VM_ID_CUSTOM,
        type_: DEFAULT_VM_TYPE,
        publicKeyMultibase: DEFAULT_VM_PUBLIC_KEY,
        blockchainAccountId: DEFAULT_VM_BLOCKCHAIN_ACCOUNT_ID,
        ethereumAddress: DEFAULT_VM_ETHEREUM_ADDRESS,
        relationships: VM_RELATIONSHIPS_ALL,
        expiration: DEFAULT_VM_EXPIRATION
      })
    );
    // Add a new Service
    ServiceUpdateResultTest memory result = _updateService(
      ServiceUpdateCommandTest({
        method0: didInfo.method0,
        method1: didInfo.method1,
        method2: didInfo.method2,
        senderId: didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: didInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    //* 🎬 Act ⬇
    // Check final state
    W3CDidDocument memory didDocument = w3cResolver.resolve(
      W3CDidInput({
        method0: didInfo.method0,
        method1: didInfo.method1,
        method2: didInfo.method2,
        id: didInfo.id,
        fragment: EMPTY_VM_ID
      }),
      false
    );
    // To compare strings, we need to call the hash of the string
    assertEq(keccak256(abi.encode(didDocument.context)), keccak256(abi.encode(DEFAULT_CONTEXT)));
    assertEq(
      keccak256(abi.encodePacked(didDocument.id)),
      keccak256(
        abi.encodePacked(
          _formatDidString(
            W3CDidInput(didInfo.method0, didInfo.method1, didInfo.method2, didInfo.id, bytes32(0))
          )
        )
      )
    );
    assertEq(
      keccak256(abi.encodePacked(didDocument.service[0].id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_SERVICE_ID)))))
    );
    // end
    vm.stopPrank();
  }

  // * Internal functions

  function _deployNewW3cResolver(
    IDidManager _didManager
  ) internal returns (IW3CResolver _w3cResolver) {
    (_w3cResolver, ) = new W3CResolverScript().deploy(
      DeployCommand({
        didManager: _didManager,
        storeInfo: DeploymentStoreInfo({ store: false, tag: bytes32(0) })
      }),
      false
    );
  }

  /**
   * @dev Updates a service.
   */
  function _updateService(
    ServiceUpdateCommandTest memory command
  ) internal returns (ServiceUpdateResultTest memory result) {
    // Event recording
    vm.recordLogs();
    //* Update controller call
    didManager.updateService(
      command.method0,
      command.method1,
      command.method2,
      command.senderId,
      command.senderVmId,
      command.targetId,
      command.serviceId,
      command.type_,
      command.serviceEndpoint
    );
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Induce performed action
    result.performedAction = entries.length == 1
      ? PerformedAction.CREATEorUPDATE
      : entries.length == 2
      ? PerformedAction.DELETE
      : PerformedAction.UNDEFINED;
    // Get the event values
    // ServiceUpdated(
    //   bytes32 indexed didIdHash,
    //   bytes32 indexed id,
    //   bytes32 indexed serviceIdHash,
    //   bytes32 positionHash
    // );
    result.ServiceUpdated_didIdHash = entries[0].topics[1];
    result.ServiceUpdated_id = entries[0].topics[2];
    result.ServiceUpdated_serviceIdHash = entries[0].topics[3];
    result.ServiceUpdated_positionHash = bytes32(entries[0].data);
  }

  function _formatDidString(W3CDidInput memory didInput) internal pure returns (string memory did) {
    bytes memory methods = abi.encodePacked(didInput.method0, ":");
    if (didInput.method1 != bytes32(0)) {
      methods = abi.encodePacked(methods, didInput.method1, ":");
    }
    if (didInput.method2 != bytes32(0)) {
      methods = abi.encodePacked(methods, didInput.method2, ":");
    }

    return
      string(
        _trimBytes(abi.encodePacked(methods, _bytesToHexString(abi.encodePacked(didInput.id))))
      );
  }

  function _trimBytes(bytes memory input) internal pure returns (bytes memory output) {
    if (input[0] == 0x00) {
      return new bytes(0);
    }
    bytes memory withoutZeros = new bytes(input.length);
    uint8 length = 0;
    for (uint8 i = 0; i < input.length; i++) {
      if (input[i] != 0x00) {
        withoutZeros[length] = input[i];
        length++;
      }
    }
    output = new bytes(length);
    for (uint8 i = 0; i < length; i++) {
      output[i] = withoutZeros[i];
    }
    return output;
  }

  function _bytesToHexString(bytes memory input) public pure returns (string memory hexString) {
    // Fixed buffer size for hexadecimal convertion
    bytes memory converted = new bytes(input.length * 2);
    bytes memory _base = "0123456789abcdef";

    for (uint256 i = 0; i < input.length; i++) {
      converted[i * 2] = _base[uint8(input[i]) / _base.length];
      converted[i * 2 + 1] = _base[uint8(input[i]) % _base.length];
    }

    return string(converted);
  }
}
