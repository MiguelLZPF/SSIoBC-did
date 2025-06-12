// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Helper } from "@script/Helper.sol";
import { Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { W3CResolverScript, DeployCommand } from "@script/W3CResolver.s.sol";
import { SharedTest, DidInfo, CreateDidResultTest, CreateVmResultTest } from "@test/SharedTest.sol";
import { PerformedAction, Service, ServiceUpdateCommandTest, ServiceUpdateResultTest } from "@test/ServiceStorage.t.sol";
import { VM_DEFAULT_EXPIRATION } from "@src/VMStorage.sol";
import { IDidManager, VerificationMethod, Controller, CreateVmCommand as DidCreateVmCommand, EXPIRATION, CONTROLLERS_MAX_LENGTH, SERVICE_MAX_LENGTH } from "@src/interfaces/IDidManager.sol";
import { IW3CResolver, W3CDidDocument, W3CVerificationMethod, W3CService, W3CDidInput } from "@src/interfaces/IW3CResolver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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

contract W3CResolverTest is SharedTest, Helper {
  //* Constants
  // Specific
  string[] private DEFAULT_CONTEXT = ["https://www.w3.org/ns/did/v1"];
  bytes32 private constant RANDOM_CREATE_DEFAULT = bytes32("This is a random value");
  bytes32 private constant RANDOM_CREATE_CUSTOM = bytes32("This is another random value");
  bytes32 private constant RANDOM_AUTHENTICATE = bytes32("Random value authenticate");
  bytes32 private constant RANDOM_RELATIONSHIP = bytes32("Random value relationship");
  bytes32 private constant VM_ID_CUSTOM = bytes32("vm_custom");
  bytes32 private constant VM_ID_CUSTOM_2 = bytes32("vm_custom_2");
  bytes32 private constant SERVICE_ID_SC = bytes32("issue-vc");
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
      abi.encodePacked(DEFAULT_DID_METHODS, RANDOM_CREATE_DEFAULT, user, block.timestamp)
    );
    uint256 exp = didManager.getExpiration(
      DEFAULT_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(DEFAULT_DID_METHODS, id);
    assertEq(length, 0);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    //* 🎬 Act ⬇
    // Check final state
    W3CVerificationMethod memory w3cVm = w3cResolver.resolveVm(
      W3CDidInput({ methods: DEFAULT_DID_METHODS, id: result.didInfo.id, fragment: EMPTY_VM_ID }),
      DEFAULT_VM_ID
    );
    //* ☑️ Assert ⬇
    assertEq(
      keccak256(abi.encodePacked(w3cVm.id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(result.VmCreated_id)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(result.VmValidated_id)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.type_)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_VM_TYPE)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.controller)),
      keccak256(
        abi.encodePacked(
          string(
            (_formatDidString(W3CDidInput(result.didInfo.methods, result.didInfo.id, bytes32(0))))
          )
        )
      )
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.publicKeyMultibase)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(EMPTY_VM_PUBLIC_KEY)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.blockchainAccountId)),
      keccak256(
        abi.encodePacked(string(_trimBytes(abi.encodePacked(EMPTY_VM_BLOCKCHAIN_ACCOUNT_ID))))
      )
    );
    assertEq(
      keccak256(abi.encodePacked(w3cVm.ethereumAddress)),
      keccak256(abi.encodePacked(Strings.toHexString(user)))
    );
    assertEq(w3cVm.expiration, (block.timestamp + VM_DEFAULT_EXPIRATION) * 1000);
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
      abi.encodePacked(DEFAULT_DID_METHODS, RANDOM_CREATE_DEFAULT, tx.origin, block.prevrandao)
    );
    uint256 exp = didManager.getExpiration(
      DEFAULT_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(DEFAULT_DID_METHODS, id);
    assertEq(length, 0);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Add a new Service
    ServiceUpdateResultTest memory updateServiceResult = _updateService(
      ServiceUpdateCommandTest({
        methods: result.didInfo.methods,
        senderId: result.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: result.didInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    //* 🎬 Act ⬇
    // Check final state
    W3CService memory w3cService = w3cResolver.resolveService(
      W3CDidInput({ methods: DEFAULT_DID_METHODS, id: result.didInfo.id, fragment: EMPTY_VM_ID }),
      DEFAULT_SERVICE_ID
    );
    //* ☑️ Assert ⬇
    assertEq(
      keccak256(abi.encodePacked(w3cService.id)),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_SERVICE_ID)))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cService.id)),
      keccak256(
        abi.encodePacked(
          string(_trimBytes(abi.encodePacked(updateServiceResult.ServiceUpdated_id)))
        )
      )
    );
    assertEq(
      keccak256(abi.encodePacked(w3cService.type_[0])),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_SERVICE_TYPE[0])))))
    );
    assertEq(
      keccak256(abi.encodePacked(w3cService.serviceEndpoint[0])),
      keccak256(abi.encodePacked(string(_trimBytes(abi.encodePacked(DEFAULT_SERVICE_ENDPOINT[0])))))
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
      DEFAULT_DID_METHODS,
      id,
      EMPTY_VM_ID // <-- To get the expiration of the DID
    );
    assertEq(exp, EMPTY_EXPIRATION);
    uint256 length = didManager.getVmListLength(DEFAULT_DID_METHODS, id);
    assertEq(length, 0);
    // Create DID
    CreateDidResultTest memory result = _createDid(
      EMPTY_DID_METHODS,
      RANDOM_CREATE_DEFAULT,
      EMPTY_VM_ID
    );
    // Add a new VM with all methods
    // Add new Verification Method
    /* CreateVmResultTest memory createVmResult = */ _createVm(
      DidCreateVmCommand({
        methods: result.didInfo.methods,
        senderId: result.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: result.didInfo.id,
        vmId: VM_ID_CUSTOM,
        type_: DEFAULT_VM_TYPE,
        publicKeyMultibase: DEFAULT_VM_PUBLIC_KEY,
        blockchainAccountId: DEFAULT_VM_BLOCKCHAIN_ACCOUNT_ID,
        ethereumAddress: DEFAULT_VM_ETHEREUM_ADDRESS,
        relationships: VM_RELATIONSHIPS_ALL,
        expiration: DEFAULT_VM_EXPIRATION
      })
    );
    // Add a new Service
    /* ServiceUpdateResultTest memory createServiceResult0 = */ _updateService(
      ServiceUpdateCommandTest({
        methods: result.didInfo.methods,
        senderId: result.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: result.didInfo.id,
        serviceId: DEFAULT_SERVICE_ID,
        type_: DEFAULT_SERVICE_TYPE,
        serviceEndpoint: DEFAULT_SERVICE_ENDPOINT
      })
    );
    /* ServiceUpdateResultTest memory createServiceResult1 = */ _updateService(
      ServiceUpdateCommandTest({
        methods: result.didInfo.methods,
        senderId: result.didInfo.id,
        senderVmId: DEFAULT_VM_ID,
        targetId: result.didInfo.id,
        serviceId: SERVICE_ID_SC,
        type_: SERVICE_TYPE_SC,
        serviceEndpoint: SERVICE_ENDPOINT_SC
      })
    );
    //* 🎬 Act ⬇
    // Check final state
    W3CDidDocument memory didDocument = w3cResolver.resolve(
      W3CDidInput({
        methods: result.didInfo.methods,
        id: result.didInfo.id,
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
          _formatDidString(W3CDidInput(result.didInfo.methods, result.didInfo.id, bytes32(0)))
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
      command.methods,
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
    // Get the method identifiers from the provided bytes32 value
    bytes10 method0 = bytes10(didInput.methods);
    bytes10 method1 = bytes10(bytes32(uint256(didInput.methods) << 80)); // Shift to get the second 10 bytes
    bytes10 method2 = bytes10(bytes32(uint256(didInput.methods) << 160)); // Shift to get the third 10 bytes
    // The final bytes buffer to be converted to string
    bytes memory finalEncode = abi.encodePacked("did:", method0, ":");
    if (method1 != bytes10(0)) {
      finalEncode = abi.encodePacked(finalEncode, method1, ":");
    }
    if (method2 != bytes10(0)) {
      finalEncode = abi.encodePacked(finalEncode, method2, ":");
    }
    finalEncode = abi.encodePacked(finalEncode, _bytesToHexString(abi.encodePacked(didInput.id)));
    if (didInput.fragment != bytes32(0)) {
      finalEncode = abi.encodePacked(finalEncode, "#", didInput.fragment);
    }
    return string(_trimBytes(finalEncode));
  }
}
