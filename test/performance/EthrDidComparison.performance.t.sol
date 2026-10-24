// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { DidCreateVmCommandNative as CreateVmCommandNative } from "@types/VmTypesNative.sol";
import { DEFAULT_VM_ID } from "@types/VmTypes.sol";
import { DEFAULT_VM_ID_NATIVE } from "@types/VmTypesNative.sol";
import { W3CDidInput } from "@types/W3CTypes.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { IW3CResolver } from "@interfaces/IW3CResolver.sol";
import { DidManagerNativeScript } from "@script/DidManagerNative.s.sol";
import { W3CResolverNativeScript } from "@script/W3CResolverNative.s.sol";
import { EthereumDIDRegistry } from "@ethr-did-registry/EthereumDIDRegistry.sol";
import { console } from "forge-std/console.sol";

/**
 * @title EthrDidComparisonPerformanceTest
 * @notice Gas of SSIoBC-did (Full and Native variants) against the ERC-1056 registry (ethr-did-registry 1.3.0)
 * @dev Method, so the numbers can be reproduced and argued about:
 *
 *  - One operation per test function, so each runs from a fresh state (setUp plus the minimum set-up the operation
 *    needs), and each is one top-level external call.
 *  - Gas is read with `vm.lastFrameGas().gasTotalUsed` straight after the call. This is the gas of the callee frame,
 *    the same figure `vm.snapshotGasLastCall` returns, without that cheatcode's write to `snapshots/`. It EXCLUDES the
 *    21,000 intrinsic transaction gas and the calldata gas; both are charged to the transaction, not to the callee.
 *    It INCLUDES every cold-access surcharge inside the callee, because `vm.cool` marks the target contract and all of
 *    its storage cold before each measured call. Calldata gas is logged separately (`calldata=`).
 *  - Payloads are equal on both sides: the same 64-byte public key string and the same service endpoint string.
 *  - `resolve`, `isAuthorized`, `identityOwner` and `validDelegate` are views: the figure is what an on-chain caller
 *    pays; an off-chain `eth_call` is free.
 *  - Ceilings are 5% above the value measured under `FOUNDRY_PROFILE=ci_thorough`. The file lives in
 *    `test/performance/`, which the CI test and coverage jobs exclude; only the `thorough` job runs it.
 *
 *  Machine-readable lines: `GAS|<label>|<gas>|calldata=<gas>`.
 */
contract EthrDidComparisonPerformanceTest is TestBase {
  // =========================================================================
  // Ceilings (5% above the value measured under ci_thorough, forge 1.8.1, 2026-10-24)
  // =========================================================================

  uint256 private constant CEIL_FULL_CREATE_DID = 291_994;
  uint256 private constant CEIL_FULL_CREATE_VM_ETH = 266_695;
  uint256 private constant CEIL_FULL_CREATE_VM_PK_N1 = 337_826;
  uint256 private constant CEIL_FULL_CREATE_VM_PK_N3 = 337_826;
  uint256 private constant CEIL_FULL_CREATE_VM_PK_N5 = 337_826;
  uint256 private constant CEIL_FULL_VALIDATE_VM = 37_125;
  uint256 private constant CEIL_FULL_UPDATE_CONTROLLER = 69_629;
  uint256 private constant CEIL_FULL_UPDATE_SERVICE = 213_627;
  uint256 private constant CEIL_FULL_RESOLVE_N1 = 224_988;
  uint256 private constant CEIL_FULL_RESOLVE_N3 = 402_325;
  uint256 private constant CEIL_FULL_RESOLVE_N5 = 579_815;
  uint256 private constant CEIL_FULL_IS_AUTHORIZED = 18_457;

  uint256 private constant CEIL_NATIVE_CREATE_DID = 222_285;
  uint256 private constant CEIL_NATIVE_CREATE_VM_ETH = 194_873;
  uint256 private constant CEIL_NATIVE_CREATE_VM_PK_N1 = 266_545;
  uint256 private constant CEIL_NATIVE_CREATE_VM_PK_N3 = 266_545;
  uint256 private constant CEIL_NATIVE_CREATE_VM_PK_N5 = 266_545;
  uint256 private constant CEIL_NATIVE_VALIDATE_VM = 35_022;
  uint256 private constant CEIL_NATIVE_UPDATE_CONTROLLER = 69_653;
  uint256 private constant CEIL_NATIVE_UPDATE_SERVICE = 213_536;
  uint256 private constant CEIL_NATIVE_RESOLVE_N1 = 201_673;
  uint256 private constant CEIL_NATIVE_RESOLVE_N3 = 332_267;
  uint256 private constant CEIL_NATIVE_RESOLVE_N5 = 462_993;
  uint256 private constant CEIL_NATIVE_IS_AUTHORIZED = 18_428;

  uint256 private constant CEIL_ETHR_CHANGE_OWNER = 72_040;
  uint256 private constant CEIL_ETHR_ADD_DELEGATE = 75_602;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_KEY_N0 = 54_560;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_KEY_N1 = 36_605;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_KEY_N3 = 36_605;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_KEY_N5 = 36_605;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N0 = 53_526;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N1 = 35_571;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N3 = 35_571;
  uint256 private constant CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N5 = 35_571;
  uint256 private constant CEIL_ETHR_IDENTITY_OWNER = 2_782;
  uint256 private constant CEIL_ETHR_VALID_DELEGATE = 3_142;

  // =========================================================================
  // Fixtures
  // =========================================================================

  /// 64-byte public key string, used as publicKeyMultibase (ours) and as the setAttribute value (ERC-1056).
  bytes private constant PUBLIC_KEY_64 = "zQ3shokFTS3brHcDQrn82RUDfQ23n1FVsyBYbepBrn4Q8nyB1abcdefghijklmno";
  /// Service endpoint, used as the updateService endpoint (ours) and as the setAttribute value (ERC-1056).
  bytes private constant SERVICE_ENDPOINT = "https://bar.example.com";
  bytes private constant SERVICE_TYPE = "LinkedDomains";
  bytes32 private constant ETHR_KEY_NAME = bytes32("did/pub/Secp256k1/veriKey/hex");
  bytes32 private constant ETHR_SERVICE_NAME = bytes32("did/svc/LinkedDomains");
  bytes32 private constant ETHR_DELEGATE_TYPE = bytes32("veriKey");
  uint256 private constant ETHR_VALIDITY = 365 days;

  address private user = Fixtures.TEST_USER_1;

  IDidManagerNative private didManagerNative;
  IW3CResolver private w3cResolverNative;
  EthereumDIDRegistry private registry;

  function setUp() public {
    _deployDidManager();
    (didManagerNative,) = new DidManagerNativeScript().deploy(false, "", false);
    (w3cResolverNative,) = new W3CResolverNativeScript().deploy(didManagerNative, false, "", false);
    registry = new EthereumDIDRegistry();
    _setupUser(user, "user");
    assertEq(PUBLIC_KEY_64.length, 64, "payload must be 64 bytes");
  }

  // =========================================================================
  // Measurement helpers
  // =========================================================================

  /// @dev Marks a contract and all its storage cold, so the next call pays first-touch costs like a real transaction.
  function _cool(address target) private {
    vm.cool(target);
  }

  /// @dev Reads the callee-frame gas of the call made immediately before. Must be the next external call.
  function _lastGas() private view returns (uint256) {
    return vm.lastFrameGas().gasTotalUsed;
  }

  function _calldataGas(bytes memory data) private pure returns (uint256 gas) {
    for (uint256 i = 0; i < data.length; i++) {
      gas += data[i] == 0 ? 4 : 16;
    }
  }

  function _record(string memory label, uint256 gas, bytes memory data, uint256 ceiling) private {
    console.log(string.concat("GAS|", label, "|", vm.toString(gas), "|calldata=", vm.toString(_calldataGas(data))));
    assertGt(gas, 0, label);
    assertLe(gas, ceiling, string.concat("ceiling exceeded: ", label));
  }

  // =========================================================================
  // SSIoBC Full variant
  // =========================================================================

  function _fullDid(address owner) private returns (DidTestHelpers.DidInfo memory info) {
    _startPrank(owner);
    info = DidTestHelpers.createDefaultDid(vm, didManager).didInfo;
    _stopPrank();
  }

  function _fullVmCommand(DidTestHelpers.DidInfo memory d, bytes32 vmId, address ethAddr, bytes memory pk)
    private
    pure
    returns (CreateVmCommand memory)
  {
    return CreateVmCommand({
      methods: d.methods,
      senderId: d.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: d.id,
      vmId: vmId,
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: pk,
      blockchainAccountId: "",
      ethereumAddress: ethAddr,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
      expiration: 0
    });
  }

  /// @dev Grows a Full document to `count` VMs in total (vm-0 exists), all Ethereum-address VMs, validated.
  function _fullGrow(DidTestHelpers.DidInfo memory d, uint256 count) private {
    for (uint256 i = 1; i < count; i++) {
      address ethAddr = makeAddr(string.concat("full-vm-", vm.toString(i)));
      _startPrank(user);
      DidTestHelpers.CreateVmResult memory r =
        DidTestHelpers.createVm(vm, didManager, _fullVmCommand(d, bytes32(i), ethAddr, ""));
      _stopPrank();
      vm.prank(ethAddr, ethAddr);
      didManager.validateVm(r.vmCreatedPositionHash, 0);
    }
  }

  function test_Full_CreateDid() public {
    _startPrank(user);
    _cool(address(didManager));
    didManager.createDid(Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0));
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "full_create_did",
      gas,
      abi.encodeCall(didManager.createDid, (Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0))),
      CEIL_FULL_CREATE_DID
    );
  }

  function test_Full_CreateVm_EthAddress() public {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    CreateVmCommand memory cmd = _fullVmCommand(d, bytes32("vm-eth"), makeAddr("vm-eth"), "");
    _startPrank(user);
    _cool(address(didManager));
    didManager.createVm(cmd);
    uint256 gas = _lastGas();
    _stopPrank();
    _record("full_create_vm_eth", gas, abi.encodeCall(didManager.createVm, (cmd)), CEIL_FULL_CREATE_VM_ETH);
  }

  function _fullCreateVmPk(uint256 count, string memory label, uint256 ceiling) private {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    _fullGrow(d, count);
    CreateVmCommand memory cmd = _fullVmCommand(d, bytes32("vm-pk"), address(0), PUBLIC_KEY_64);
    _startPrank(user);
    _cool(address(didManager));
    didManager.createVm(cmd);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(label, gas, abi.encodeCall(didManager.createVm, (cmd)), ceiling);
  }

  function test_Full_CreateVm_PublicKey_N1() public {
    _fullCreateVmPk(1, "full_create_vm_pk_n1", CEIL_FULL_CREATE_VM_PK_N1);
  }

  function test_Full_CreateVm_PublicKey_N3() public {
    _fullCreateVmPk(3, "full_create_vm_pk_n3", CEIL_FULL_CREATE_VM_PK_N3);
  }

  function test_Full_CreateVm_PublicKey_N5() public {
    _fullCreateVmPk(5, "full_create_vm_pk_n5", CEIL_FULL_CREATE_VM_PK_N5);
  }

  function test_Full_ValidateVm() public {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    address ethAddr = makeAddr("vm-eth");
    _startPrank(user);
    DidTestHelpers.CreateVmResult memory r =
      DidTestHelpers.createVm(vm, didManager, _fullVmCommand(d, bytes32("vm-eth"), ethAddr, ""));
    _stopPrank();
    _startPrank(ethAddr);
    _cool(address(didManager));
    didManager.validateVm(r.vmCreatedPositionHash, 0);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "full_validate_vm",
      gas,
      abi.encodeCall(didManager.validateVm, (r.vmCreatedPositionHash, 0)),
      CEIL_FULL_VALIDATE_VM
    );
  }

  function test_Full_UpdateController() public {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    DidTestHelpers.DidInfo memory c = _fullDid(Fixtures.TEST_USER_2);
    _startPrank(user);
    _cool(address(didManager));
    didManager.updateController(d.methods, d.id, DEFAULT_VM_ID, d.id, c.id, bytes32(0), 0);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "full_update_controller",
      gas,
      abi.encodeCall(didManager.updateController, (d.methods, d.id, DEFAULT_VM_ID, d.id, c.id, bytes32(0), 0)),
      CEIL_FULL_UPDATE_CONTROLLER
    );
  }

  function test_Full_UpdateService() public {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    _startPrank(user);
    _cool(address(didManager));
    didManager.updateService(
      d.methods, d.id, DEFAULT_VM_ID, d.id, Fixtures.DEFAULT_SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT
    );
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "full_update_service",
      gas,
      abi.encodeCall(
        didManager.updateService,
        (d.methods, d.id, DEFAULT_VM_ID, d.id, Fixtures.DEFAULT_SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT)
      ),
      CEIL_FULL_UPDATE_SERVICE
    );
  }

  function _fullResolve(uint256 count, string memory label, uint256 ceiling) private {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    _fullGrow(d, count);
    W3CDidInput memory input = W3CDidInput({ methods: d.methods, id: d.id, fragment: bytes32(0) });
    _cool(address(didManager));
    _cool(address(w3cResolver));
    w3cResolver.resolve(input, false);
    uint256 gas = _lastGas();
    _record(label, gas, abi.encodeCall(w3cResolver.resolve, (input, false)), ceiling);
  }

  function test_Full_Resolve_N1() public {
    _fullResolve(1, "full_resolve_n1", CEIL_FULL_RESOLVE_N1);
  }

  function test_Full_Resolve_N3() public {
    _fullResolve(3, "full_resolve_n3", CEIL_FULL_RESOLVE_N3);
  }

  function test_Full_Resolve_N5() public {
    _fullResolve(5, "full_resolve_n5", CEIL_FULL_RESOLVE_N5);
  }

  function test_Full_IsAuthorized() public {
    DidTestHelpers.DidInfo memory d = _fullDid(user);
    _cool(address(didManager));
    bool ok =
      didManager.isAuthorized(d.methods, d.id, DEFAULT_VM_ID, d.id, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user);
    uint256 gas = _lastGas();
    assertTrue(ok);
    _record(
      "full_is_authorized",
      gas,
      abi.encodeCall(
        didManager.isAuthorized, (d.methods, d.id, DEFAULT_VM_ID, d.id, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user)
      ),
      CEIL_FULL_IS_AUTHORIZED
    );
  }

  // =========================================================================
  // SSIoBC Native variant
  // =========================================================================

  function _nativeDid(address owner) private returns (DidTestHelpersNative.DidInfo memory info) {
    _startPrank(owner);
    info = DidTestHelpersNative.createDefaultDid(vm, didManagerNative).didInfo;
    _stopPrank();
  }

  function _nativeVmCommand(
    DidTestHelpersNative.DidInfo memory d,
    bytes32 vmId,
    address ethAddr,
    bytes1 relationships,
    bytes memory pk
  ) private pure returns (CreateVmCommandNative memory) {
    return CreateVmCommandNative({
      methods: d.methods,
      senderId: d.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: d.id,
      vmId: vmId,
      ethereumAddress: ethAddr,
      relationships: relationships,
      publicKeyMultibase: pk
    });
  }

  function _nativeGrow(DidTestHelpersNative.DidInfo memory d, uint256 count) private {
    for (uint256 i = 1; i < count; i++) {
      address ethAddr = makeAddr(string.concat("native-vm-", vm.toString(i)));
      _startPrank(user);
      DidTestHelpersNative.CreateVmResult memory r = DidTestHelpersNative.createVm(
        vm, didManagerNative, _nativeVmCommand(d, bytes32(i), ethAddr, Fixtures.DEFAULT_VM_RELATIONSHIPS, "")
      );
      _stopPrank();
      vm.prank(ethAddr, ethAddr);
      didManagerNative.validateVm(r.vmCreatedPositionHash, 0);
    }
  }

  function test_Native_CreateDid() public {
    _startPrank(user);
    _cool(address(didManagerNative));
    didManagerNative.createDid(Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0));
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "native_create_did",
      gas,
      abi.encodeCall(didManagerNative.createDid, (Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0))),
      CEIL_NATIVE_CREATE_DID
    );
  }

  function test_Native_CreateVm_EthAddress() public {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    CreateVmCommandNative memory cmd =
      _nativeVmCommand(d, bytes32("vm-eth"), makeAddr("vm-eth"), Fixtures.DEFAULT_VM_RELATIONSHIPS, "");
    _startPrank(user);
    _cool(address(didManagerNative));
    didManagerNative.createVm(cmd);
    uint256 gas = _lastGas();
    _stopPrank();
    _record("native_create_vm_eth", gas, abi.encodeCall(didManagerNative.createVm, (cmd)), CEIL_NATIVE_CREATE_VM_ETH);
  }

  /// @dev The Native variant stores a publicKeyMultibase only for keyAgreement VMs, and always with an address.
  function _nativeCreateVmPk(uint256 count, string memory label, uint256 ceiling) private {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    _nativeGrow(d, count);
    CreateVmCommandNative memory cmd = _nativeVmCommand(
      d, bytes32("vm-pk"), makeAddr("vm-pk"), Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT, PUBLIC_KEY_64
    );
    _startPrank(user);
    _cool(address(didManagerNative));
    didManagerNative.createVm(cmd);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(label, gas, abi.encodeCall(didManagerNative.createVm, (cmd)), ceiling);
  }

  function test_Native_CreateVm_PublicKey_N1() public {
    _nativeCreateVmPk(1, "native_create_vm_pk_n1", CEIL_NATIVE_CREATE_VM_PK_N1);
  }

  function test_Native_CreateVm_PublicKey_N3() public {
    _nativeCreateVmPk(3, "native_create_vm_pk_n3", CEIL_NATIVE_CREATE_VM_PK_N3);
  }

  function test_Native_CreateVm_PublicKey_N5() public {
    _nativeCreateVmPk(5, "native_create_vm_pk_n5", CEIL_NATIVE_CREATE_VM_PK_N5);
  }

  function test_Native_ValidateVm() public {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    address ethAddr = makeAddr("vm-eth");
    _startPrank(user);
    DidTestHelpersNative.CreateVmResult memory r = DidTestHelpersNative.createVm(
      vm, didManagerNative, _nativeVmCommand(d, bytes32("vm-eth"), ethAddr, Fixtures.DEFAULT_VM_RELATIONSHIPS, "")
    );
    _stopPrank();
    _startPrank(ethAddr);
    _cool(address(didManagerNative));
    didManagerNative.validateVm(r.vmCreatedPositionHash, 0);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "native_validate_vm",
      gas,
      abi.encodeCall(didManagerNative.validateVm, (r.vmCreatedPositionHash, 0)),
      CEIL_NATIVE_VALIDATE_VM
    );
  }

  function test_Native_UpdateController() public {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    DidTestHelpersNative.DidInfo memory c = _nativeDid(Fixtures.TEST_USER_2);
    _startPrank(user);
    _cool(address(didManagerNative));
    didManagerNative.updateController(d.methods, d.id, DEFAULT_VM_ID_NATIVE, d.id, c.id, bytes32(0), 0);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "native_update_controller",
      gas,
      abi.encodeCall(
        didManagerNative.updateController, (d.methods, d.id, DEFAULT_VM_ID_NATIVE, d.id, c.id, bytes32(0), 0)
      ),
      CEIL_NATIVE_UPDATE_CONTROLLER
    );
  }

  function test_Native_UpdateService() public {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    _startPrank(user);
    _cool(address(didManagerNative));
    didManagerNative.updateService(
      d.methods, d.id, DEFAULT_VM_ID_NATIVE, d.id, Fixtures.DEFAULT_SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT
    );
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      "native_update_service",
      gas,
      abi.encodeCall(
        didManagerNative.updateService,
        (d.methods, d.id, DEFAULT_VM_ID_NATIVE, d.id, Fixtures.DEFAULT_SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT)
      ),
      CEIL_NATIVE_UPDATE_SERVICE
    );
  }

  function _nativeResolve(uint256 count, string memory label, uint256 ceiling) private {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    _nativeGrow(d, count);
    W3CDidInput memory input = W3CDidInput({ methods: d.methods, id: d.id, fragment: bytes32(0) });
    _cool(address(didManagerNative));
    _cool(address(w3cResolverNative));
    w3cResolverNative.resolve(input, false);
    uint256 gas = _lastGas();
    _record(label, gas, abi.encodeCall(w3cResolverNative.resolve, (input, false)), ceiling);
  }

  function test_Native_Resolve_N1() public {
    _nativeResolve(1, "native_resolve_n1", CEIL_NATIVE_RESOLVE_N1);
  }

  function test_Native_Resolve_N3() public {
    _nativeResolve(3, "native_resolve_n3", CEIL_NATIVE_RESOLVE_N3);
  }

  function test_Native_Resolve_N5() public {
    _nativeResolve(5, "native_resolve_n5", CEIL_NATIVE_RESOLVE_N5);
  }

  function test_Native_IsAuthorized() public {
    DidTestHelpersNative.DidInfo memory d = _nativeDid(user);
    _cool(address(didManagerNative));
    bool ok = didManagerNative.isAuthorized(
      d.methods, d.id, DEFAULT_VM_ID_NATIVE, d.id, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user
    );
    uint256 gas = _lastGas();
    assertTrue(ok);
    _record(
      "native_is_authorized",
      gas,
      abi.encodeCall(
        didManagerNative.isAuthorized,
        (d.methods, d.id, DEFAULT_VM_ID_NATIVE, d.id, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user)
      ),
      CEIL_NATIVE_IS_AUTHORIZED
    );
  }

  // =========================================================================
  // ERC-1056 registry
  // =========================================================================

  /// @dev "Creating" an ERC-1056 identity is not a transaction: any address is its own owner from the start.
  function test_Ethr_ImplicitCreate_IsFree() public {
    address fresh = makeAddr("never-used-before");
    assertEq(registry.identityOwner(fresh), fresh);
    console.log("GAS|ethr_implicit_create|0|calldata=0");
  }

  function test_Ethr_ChangeOwner() public {
    address newOwner = makeAddr("new-owner");
    _startPrank(user);
    _cool(address(registry));
    registry.changeOwner(user, newOwner);
    uint256 gas = _lastGas();
    _stopPrank();
    assertEq(registry.identityOwner(user), newOwner);
    _record(
      "ethr_change_owner",
      gas,
      abi.encodeWithSignature("changeOwner(address,address)", user, newOwner),
      CEIL_ETHR_CHANGE_OWNER
    );
  }

  function test_Ethr_AddDelegate() public {
    address delegate = makeAddr("delegate");
    _startPrank(user);
    _cool(address(registry));
    registry.addDelegate(user, ETHR_DELEGATE_TYPE, delegate, ETHR_VALIDITY);
    uint256 gas = _lastGas();
    _stopPrank();
    assertTrue(registry.validDelegate(user, ETHR_DELEGATE_TYPE, delegate));
    _record(
      "ethr_add_delegate",
      gas,
      abi.encodeWithSignature(
        "addDelegate(address,bytes32,address,uint256)", user, ETHR_DELEGATE_TYPE, delegate, ETHR_VALIDITY
      ),
      CEIL_ETHR_ADD_DELEGATE
    );
  }

  /// @dev Sets `n` key attributes (one per block), then measures one more of the requested kind in a new block.
  function _ethrSetAttribute(uint256 n, bool service, string memory label, uint256 ceiling) private {
    _startPrank(user);
    for (uint256 i = 0; i < n; i++) {
      vm.roll(block.number + 1);
      registry.setAttribute(user, ETHR_KEY_NAME, PUBLIC_KEY_64, ETHR_VALIDITY);
    }
    bytes32 name = service ? ETHR_SERVICE_NAME : ETHR_KEY_NAME;
    bytes memory value = service ? SERVICE_ENDPOINT : PUBLIC_KEY_64;
    vm.roll(block.number + 1);
    _cool(address(registry));
    registry.setAttribute(user, name, value, ETHR_VALIDITY);
    uint256 gas = _lastGas();
    _stopPrank();
    _record(
      label,
      gas,
      abi.encodeWithSignature("setAttribute(address,bytes32,bytes,uint256)", user, name, value, ETHR_VALIDITY),
      ceiling
    );
  }

  function test_Ethr_SetAttribute_Key_N0() public {
    _ethrSetAttribute(0, false, "ethr_set_attribute_key_n0", CEIL_ETHR_SET_ATTRIBUTE_KEY_N0);
  }

  function test_Ethr_SetAttribute_Key_N1() public {
    _ethrSetAttribute(1, false, "ethr_set_attribute_key_n1", CEIL_ETHR_SET_ATTRIBUTE_KEY_N1);
  }

  function test_Ethr_SetAttribute_Key_N3() public {
    _ethrSetAttribute(3, false, "ethr_set_attribute_key_n3", CEIL_ETHR_SET_ATTRIBUTE_KEY_N3);
  }

  function test_Ethr_SetAttribute_Key_N5() public {
    _ethrSetAttribute(5, false, "ethr_set_attribute_key_n5", CEIL_ETHR_SET_ATTRIBUTE_KEY_N5);
  }

  function test_Ethr_SetAttribute_Service_N0() public {
    _ethrSetAttribute(0, true, "ethr_set_attribute_service_n0", CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N0);
  }

  function test_Ethr_SetAttribute_Service_N1() public {
    _ethrSetAttribute(1, true, "ethr_set_attribute_service_n1", CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N1);
  }

  function test_Ethr_SetAttribute_Service_N3() public {
    _ethrSetAttribute(3, true, "ethr_set_attribute_service_n3", CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N3);
  }

  function test_Ethr_SetAttribute_Service_N5() public {
    _ethrSetAttribute(5, true, "ethr_set_attribute_service_n5", CEIL_ETHR_SET_ATTRIBUTE_SERVICE_N5);
  }

  function test_Ethr_IdentityOwner() public {
    _cool(address(registry));
    address owner = registry.identityOwner(user);
    uint256 gas = _lastGas();
    assertEq(owner, user);
    _record(
      "ethr_identity_owner", gas, abi.encodeWithSignature("identityOwner(address)", user), CEIL_ETHR_IDENTITY_OWNER
    );
  }

  function test_Ethr_ValidDelegate() public {
    address delegate = makeAddr("delegate");
    vm.prank(user, user);
    registry.addDelegate(user, ETHR_DELEGATE_TYPE, delegate, ETHR_VALIDITY);
    _cool(address(registry));
    bool ok = registry.validDelegate(user, ETHR_DELEGATE_TYPE, delegate);
    uint256 gas = _lastGas();
    assertTrue(ok);
    _record(
      "ethr_valid_delegate",
      gas,
      abi.encodeWithSignature("validDelegate(address,bytes32,address)", user, ETHR_DELEGATE_TYPE, delegate),
      CEIL_ETHR_VALID_DELEGATE
    );
  }
}
