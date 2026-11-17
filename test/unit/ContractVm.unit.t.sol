// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { DidTestHelpers } from "@test/helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "@test/helpers/DidTestHelpersNative.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import {
  ReferenceIssuer,
  OpenCaller,
  MockMultisig,
  ConstructorValidator,
  RelayedDelegate,
  MetamorphicFactory
} from "@test/mocks/MockContractKeys.sol";
import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";
import { IDidReadOps } from "@interfaces/IDidReadOps.sol";
import { IDidAuth } from "@interfaces/IDidAuth.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { IVMStorage, DEFAULT_VM_ID } from "@interfaces/IVMStorage.sol";
import { IVMStorageNative, DEFAULT_VM_ID_NATIVE } from "@interfaces/IVMStorageNative.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { DidCreateVmCommandNative as NativeCreateVmCommand } from "@types/VmTypesNative.sol";
import "@types/DidTypes.sol";

/// @dev Both variants expose the same selectors for what these tests read.
interface IManager is IDidWriteOps, IDidReadOps, IDidAuth { }

// =========================================================================
// Shared cases (run on both variants)
// =========================================================================

abstract contract CasesBase is Test {
  event VmValidated(bytes32 indexed id);

  bytes4 internal constant INVALID_SIGNATURE = bytes4(keccak256("InvalidSignature()"));
  bytes4 internal constant VM_NOT_FOUND = bytes4(keccak256("VmNotFound()"));
  bytes4 internal constant VM_ALREADY_VALIDATED = bytes4(keccak256("VmAlreadyValidated()"));
  bytes4 internal constant VM_ALREADY_EXPIRED = bytes4(keccak256("VmAlreadyExpired()"));

  bytes1 internal constant R_ASSERTION = 0x02;
  bytes1 internal constant R_ALL = 0x1F;
  bytes32 internal constant VM_T = bytes32("vm-t");

  address internal owner = makeAddr("owner");
  address internal admin = makeAddr("admin");
  address internal stranger = makeAddr("stranger");
  address internal relayer = makeAddr("relayer");

  function _mgr() internal view virtual returns (address);
  function _defaultVmId() internal pure virtual returns (bytes32);
  function _newDid(address who, bytes32 random) internal virtual returns (bytes32 methods, bytes32 id);
  function _newVm(address who, bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    virtual
    returns (bytes32 positionHash);
  function _createVmCalldata(bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    view
    virtual
    returns (bytes memory);

  function _auth(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 rel, address key) internal view returns (bool) {
    return IManager(_mgr()).isAuthorized(methods, id, vmId, id, rel, key);
  }

  function _validateCalldata(bytes32 pos) internal pure returns (bytes memory) {
    return abi.encodeCall(IDidWriteOps.validateVm, (pos, 0));
  }

  /// @dev The seven authenticated writes that change a DID document, each one guarded by onlyDirectEOA.
  function _guardedCalls(bytes32 methods, bytes32 id, bytes32 vmId, address key)
    internal
    view
    returns (bytes[] memory c)
  {
    bytes32 dv = _defaultVmId();
    c = new bytes[](7);
    c[0] = abi.encodeCall(IDidWriteOps.createDid, (methods, bytes32("rnd-new"), bytes32(0)));
    c[1] = _createVmCalldata(methods, id, bytes32("vm-new"), key, R_ASSERTION);
    c[2] = abi.encodeCall(IDidWriteOps.expireVm, (methods, id, vmId, id, dv));
    c[3] = abi.encodeCall(IDidWriteOps.deactivateDid, (methods, id, vmId, id));
    c[4] = abi.encodeCall(IDidWriteOps.reactivateDid, (methods, id, vmId, id));
    c[5] = abi.encodeCall(IDidWriteOps.updateController, (methods, id, vmId, id, id, vmId, 0));
    c[6] = abi.encodeCall(IDidWriteOps.updateService, (methods, id, vmId, id, bytes32("svc"), bytes("t"), bytes("e")));
  }
}

abstract contract Cases is CasesBase {
  // 1
  function test_ValidateVm_Should_Activate_When_ContractValidatesItself() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r1"));
    ReferenceIssuer issuer = new ReferenceIssuer(_mgr(), admin);
    bytes32 pos = _newVm(owner, m, id, VM_T, address(issuer), R_ASSERTION);
    assertFalse(_auth(m, id, VM_T, R_ASSERTION, address(issuer)), "pending VM must not authorize");

    vm.expectEmit(true, false, false, false, _mgr());
    emit VmValidated(VM_T);
    vm.prank(admin, admin);
    issuer.validate(pos);

    assertEq(IManager(_mgr()).getExpiration(m, id, VM_T), block.timestamp + 365 days, "default expiration");
    assertTrue(_auth(m, id, VM_T, R_ASSERTION, address(issuer)), "issuer authorized");
    assertFalse(_auth(m, id, VM_T, R_ASSERTION, admin), "admin address is not a key of the DID");
  }

  // 2
  function test_RevertWhen_ValidateVm_CallerIsNotTheVmAddress() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r2"));
    ReferenceIssuer issuer = new ReferenceIssuer(_mgr(), admin);
    OpenCaller other = new OpenCaller();
    bytes32 pos = _newVm(owner, m, id, VM_T, address(issuer), R_ASSERTION);

    vm.prank(stranger, stranger);
    vm.expectRevert(INVALID_SIGNATURE);
    other.exec(_mgr(), _validateCalldata(pos));

    vm.prank(stranger, stranger);
    vm.expectRevert(INVALID_SIGNATURE);
    IManager(_mgr()).validateVm(pos, 0);

    vm.prank(stranger, stranger);
    vm.expectRevert(ReferenceIssuer.NotAdmin.selector);
    issuer.validate(pos);
  }

  // 3
  function test_ValidateVm_Should_Activate_When_ContractAdminIsAContract() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r3"));
    MockMultisig multisig = new MockMultisig();
    ReferenceIssuer issuer = new ReferenceIssuer(_mgr(), address(multisig));
    bytes32 pos = _newVm(owner, m, id, VM_T, address(issuer), R_ASSERTION);

    vm.prank(admin, admin);
    multisig.exec(address(issuer), abi.encodeCall(ReferenceIssuer.validate, (pos)));

    assertTrue(_auth(m, id, VM_T, R_ASSERTION, address(issuer)), "issuer authorized");
  }

  // 4
  function test_RevertWhen_ValidateVm_IntermediaryTriesUsersVm() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r4"));
    address u = makeAddr("u");
    OpenCaller opener = new OpenCaller();
    bytes32 posU = _newVm(owner, m, id, VM_T, u, R_ASSERTION);

    vm.prank(u, u);
    vm.expectRevert(INVALID_SIGNATURE);
    opener.exec(_mgr(), _validateCalldata(posU));

    assertEq(IManager(_mgr()).getExpiration(m, id, VM_T), 0, "VM stays pending");
  }

  // 5
  function test_ValidateVm_Should_Activate_When_OpenCallerIsDrivenByStranger() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r5"));
    OpenCaller opener = new OpenCaller();
    bytes32 pos = _newVm(owner, m, id, VM_T, address(opener), R_ALL);

    vm.prank(stranger, stranger);
    opener.exec(_mgr(), _validateCalldata(pos));
    assertTrue(_auth(m, id, VM_T, R_ALL, address(opener)), "validated by a stranger");

    bytes[] memory calls = _guardedCalls(m, id, VM_T, address(opener));
    for (uint256 i; i < calls.length; i++) {
      vm.prank(stranger, stranger);
      vm.expectRevert(DirectEOACallRequired.selector);
      opener.exec(_mgr(), calls[i]);
    }
  }

  // 6
  function test_ValidateVm_Should_Activate_When_CalledFromConstructor() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r6"));
    address predicted = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes32 pos = _newVm(owner, m, id, VM_T, predicted, R_ASSERTION);

    ConstructorValidator c = new ConstructorValidator(_mgr(), pos, false);

    assertEq(address(c), predicted, "CREATE address precomputed");
    assertTrue(_auth(m, id, VM_T, R_ASSERTION, predicted), "constructor validated itself");
  }

  // 7
  function test_ValidateVm_Should_Activate_When_7702DelegateIsDrivenByRelayer() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r7"));
    uint256 pk = 0xB0B;
    address a = vm.addr(pk);
    RelayedDelegate delegate = new RelayedDelegate();

    vm.signAndAttachDelegation(address(delegate), pk);
    bytes32 pos = _newVm(owner, m, id, VM_T, a, R_ASSERTION); // the next call applies the delegation
    bytes32 posSelf = _newVm(owner, m, id, bytes32("vm-self"), a, R_ASSERTION);
    assertGt(a.code.length, 0, "account carries the delegation");

    vm.prank(relayer, relayer);
    RelayedDelegate(a).execute(_mgr(), _validateCalldata(pos));
    assertTrue(_auth(m, id, VM_T, R_ASSERTION, a), "relayed validation");

    vm.prank(a, a);
    IManager(_mgr()).validateVm(posSelf, 0);
    assertTrue(_auth(m, id, bytes32("vm-self"), R_ASSERTION, a), "direct validation");
  }

  // 8
  function test_ValidateVm_EoaPathUnchanged() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r8"));
    address eoa = makeAddr("eoa");
    bytes32 pos = _newVm(owner, m, id, VM_T, eoa, R_ASSERTION);

    vm.prank(stranger, stranger);
    vm.expectRevert(INVALID_SIGNATURE);
    IManager(_mgr()).validateVm(pos, 0);

    vm.expectEmit(true, false, false, false, _mgr());
    emit VmValidated(VM_T);
    vm.prank(eoa, eoa);
    IManager(_mgr()).validateVm(pos, 0);
    assertTrue(_auth(m, id, VM_T, R_ASSERTION, eoa), "EOA validated");

    vm.prank(eoa, eoa);
    vm.expectRevert(VM_ALREADY_VALIDATED);
    IManager(_mgr()).validateVm(pos, 0);

    vm.prank(eoa, eoa);
    vm.expectRevert(VM_NOT_FOUND);
    IManager(_mgr()).validateVm(bytes32("nope"), 0);
  }

  // 9
  function test_RevertWhen_ContractKeyCallsAnyGuardedWrite() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r9"));
    ReferenceIssuer issuer = new ReferenceIssuer(_mgr(), admin);
    bytes32 pos = _newVm(owner, m, id, VM_T, address(issuer), R_ALL);
    vm.prank(admin, admin);
    issuer.validate(pos);
    assertTrue(_auth(m, id, VM_T, R_ALL, address(issuer)), "issuer validated");

    bytes[] memory calls = _guardedCalls(m, id, VM_T, address(issuer));
    for (uint256 i; i < calls.length; i++) {
      vm.prank(admin, admin);
      vm.expectRevert(DirectEOACallRequired.selector);
      issuer.exec(_mgr(), calls[i]);
    }

    // The owner expires the owner's own EOA key: nobody can write the DID any more.
    vm.prank(owner, owner);
    IManager(_mgr()).expireVm(m, id, _defaultVmId(), id, _defaultVmId());
    vm.prank(admin, admin);
    vm.expectRevert(DirectEOACallRequired.selector);
    issuer.exec(_mgr(), calls[6]);
    vm.prank(owner, owner);
    vm.expectRevert(VM_ALREADY_EXPIRED);
    IManager(_mgr()).updateService(m, id, _defaultVmId(), id, bytes32("svc"), bytes("t"), bytes("e"));
  }

  // 10
  function test_RevertWhen_ValidateVm_ContractUsesUnknownPosition() public {
    OpenCaller opener = new OpenCaller();
    vm.expectRevert(VM_NOT_FOUND);
    opener.exec(_mgr(), _validateCalldata(bytes32("nope")));
  }

  // 12
  function test_DeactivateReactivate_Should_PreserveContractVm() public {
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("r12"));
    ReferenceIssuer issuer = new ReferenceIssuer(_mgr(), admin);
    bytes32 pos = _newVm(owner, m, id, VM_T, address(issuer), R_ASSERTION);
    vm.prank(admin, admin);
    issuer.validate(pos);
    assertTrue(_auth(m, id, VM_T, R_ASSERTION, address(issuer)), "before");

    vm.prank(owner, owner);
    IManager(_mgr()).deactivateDid(m, id, _defaultVmId(), id);
    assertFalse(_auth(m, id, VM_T, R_ASSERTION, address(issuer)), "while deactivated");

    vm.prank(owner, owner);
    IManager(_mgr()).reactivateDid(m, id, _defaultVmId(), id);
    assertTrue(_auth(m, id, VM_T, R_ASSERTION, address(issuer)), "after reactivation");
  }
}

// =========================================================================
// Metamorphic case: its own setUp, so a failure here cannot hide the other tests
// =========================================================================

abstract contract MetamorphicCases is CasesBase {
  bytes32 internal constant META_SALT = bytes32("meta-salt");

  // Set in setUp for the metamorphic case (the creating transaction must end before the redeploy)
  MetamorphicFactory internal factory;
  bytes32 internal metaMethods;
  bytes32 internal metaId;
  address internal metaAddress;

  function _initMeta() internal {
    factory = new MetamorphicFactory();
    (metaMethods, metaId) = _newDid(owner, bytes32("meta-did"));
    metaAddress = factory.predict(META_SALT);
    bytes32 pos = _newVm(owner, metaMethods, metaId, VM_T, metaAddress, R_ASSERTION);
    assertEq(factory.deployValidator(META_SALT, _mgr(), pos), metaAddress, "validator at predicted address");
  }

  // 11
  function test_ValidateVm_Should_KeepAddressBinding_When_CodeChangesAfterValidation() public {
    assertEq(metaAddress.code.length, 0, "validator destroyed itself");
    assertTrue(_auth(metaMethods, metaId, VM_T, R_ASSERTION, metaAddress), "authorized with no code");

    address redeployed = factory.deployRuntime(META_SALT, type(OpenCaller).runtimeCode);

    assertEq(redeployed, metaAddress, "same address, different code");
    assertGt(redeployed.code.length, 0, "new code present");
    assertTrue(_auth(metaMethods, metaId, VM_T, R_ASSERTION, metaAddress), "binding survives the redeploy");
  }
}

// =========================================================================
// Full W3C Variant
// =========================================================================

abstract contract ContractVmFullBase is CasesBase, TestBase {
  function _mgr() internal view override returns (address) {
    return address(didManager);
  }

  function _defaultVmId() internal pure override returns (bytes32) {
    return DEFAULT_VM_ID;
  }

  function _newDid(address who, bytes32 random) internal override returns (bytes32, bytes32) {
    vm.startPrank(who, who);
    DidTestHelpers.CreateDidResult memory r =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, random, bytes32(0));
    vm.stopPrank();
    return (r.didInfo.methods, r.didInfo.id);
  }

  function _cmd(bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    pure
    returns (CreateVmCommand memory)
  {
    return CreateVmCommand({
      methods: methods,
      senderId: id,
      senderVmId: DEFAULT_VM_ID,
      targetId: id,
      vmId: vmId,
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: rel & 0x04 != 0
        ? Fixtures.defaultVmPublicKeyMultibase()
        : Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: key,
      relationships: rel,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
  }

  function _newVm(address who, bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    override
    returns (bytes32)
  {
    vm.startPrank(who, who);
    DidTestHelpers.CreateVmResult memory r = DidTestHelpers.createVm(vm, didManager, _cmd(methods, id, vmId, key, rel));
    vm.stopPrank();
    return r.vmCreatedPositionHash;
  }

  function _createVmCalldata(bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    pure
    override
    returns (bytes memory)
  {
    return abi.encodeCall(IDidManagerFull.createVm, (_cmd(methods, id, vmId, key, rel)));
  }
}

// =========================================================================
// Ethereum-Native Variant
// =========================================================================

abstract contract ContractVmNativeBase is CasesBase, TestBaseNative {
  function _mgr() internal view override returns (address) {
    return address(didManagerNative);
  }

  function _defaultVmId() internal pure override returns (bytes32) {
    return DEFAULT_VM_ID_NATIVE;
  }

  function _newDid(address who, bytes32 random) internal override returns (bytes32, bytes32) {
    vm.startPrank(who, who);
    DidTestHelpersNative.CreateDidResult memory r =
      DidTestHelpersNative.createDid(vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, random, bytes32(0));
    vm.stopPrank();
    return (r.didInfo.methods, r.didInfo.id);
  }

  function _cmd(bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    pure
    returns (NativeCreateVmCommand memory)
  {
    return NativeCreateVmCommand({
      methods: methods,
      senderId: id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: id,
      vmId: vmId,
      ethereumAddress: key,
      relationships: rel,
      publicKeyMultibase: rel & 0x04 != 0 ? Fixtures.defaultVmPublicKeyMultibase() : bytes("")
    });
  }

  function _newVm(address who, bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    override
    returns (bytes32)
  {
    vm.startPrank(who, who);
    DidTestHelpersNative.CreateVmResult memory r =
      DidTestHelpersNative.createVm(vm, didManagerNative, _cmd(methods, id, vmId, key, rel));
    vm.stopPrank();
    return r.vmCreatedPositionHash;
  }

  function _createVmCalldata(bytes32 methods, bytes32 id, bytes32 vmId, address key, bytes1 rel)
    internal
    pure
    override
    returns (bytes memory)
  {
    return abi.encodeCall(IDidManagerNative.createVm, (_cmd(methods, id, vmId, key, rel)));
  }
}

contract ContractVmUnitTest is Cases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
  }
}

contract ContractVmNativeUnitTest is Cases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
  }
}

contract ContractVmMetamorphicTest is MetamorphicCases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
    _initMeta();
  }
}

contract ContractVmNativeMetamorphicTest is MetamorphicCases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
    _initMeta();
  }
}
