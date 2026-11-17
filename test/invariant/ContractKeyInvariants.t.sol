// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Vm } from "forge-std/Vm.sol";
import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import { ReferenceIssuer, OpenCaller } from "@test/mocks/MockContractKeys.sol";
import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";
import { IDidReadOps } from "@interfaces/IDidReadOps.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { DEFAULT_VM_ID } from "@interfaces/IVMStorage.sol";
import { DEFAULT_VM_ID_NATIVE } from "@interfaces/IVMStorageNative.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { DidCreateVmCommandNative as NativeCreateVmCommand } from "@types/VmTypesNative.sol";
import { DEFAULT_DID_METHODS } from "@types/DidTypes.sol";

/**
 * @title ContractKeyHandlerBase
 * @notice Drives a manager with EOAs and contracts as verification-method keys (v1.8.0).
 * @dev Every action is wrapped so it never reverts. Ghost state is keyed by position hash, because VM ids
 * repeat across DIDs. Only VMs created here with createVm are tracked: the first VM of a DID is validated
 * inside createDid and has no position hash in the handler.
 */
abstract contract ContractKeyHandlerBase is Test {
  struct DidRef {
    bytes32 methods;
    bytes32 id;
    address owner;
  }

  struct VmRef {
    uint256 didIndex;
    bytes32 vmId;
  }

  bytes1 internal constant R_ALL = 0x1F;

  address internal immutable MGR;
  address internal immutable ADMIN_SELF;

  address[2] internal owners;
  address[3] internal eoaKeys;
  address[3] internal contractKeys; // two ReferenceIssuer (this handler is admin) and one OpenCaller
  address internal stranger;

  DidRef[] internal dids;
  bytes32[] internal tracked;
  mapping(bytes32 => VmRef) internal vmRefs;
  uint256 internal nonce;

  // Ghost state, keyed by position hash
  mapping(bytes32 => address) public ghost_boundTo;
  mapping(bytes32 => address) public ghost_validatedBy;
  uint256 public ghost_eoaMismatch;
  uint256 public ghost_guardedWriteSuccessFromContract;

  // Reach counters
  uint256 public totalCalls;
  uint256 public contractValidationAttempts;
  uint256 public contractValidationSuccesses;
  uint256 public contractWriteAttempts;
  uint256 public eoaRightAttempts;
  uint256 public eoaWrongAttempts;

  constructor(address manager) {
    MGR = manager;
    ADMIN_SELF = address(this);
    owners[0] = makeAddr("owner-0");
    owners[1] = makeAddr("owner-1");
    eoaKeys[0] = makeAddr("eoa-key-0");
    eoaKeys[1] = makeAddr("eoa-key-1");
    eoaKeys[2] = makeAddr("eoa-key-2");
    contractKeys[0] = address(new ReferenceIssuer(manager, address(this)));
    contractKeys[1] = address(new ReferenceIssuer(manager, address(this)));
    contractKeys[2] = address(new OpenCaller());
    stranger = makeAddr("stranger");
  }

  // ---- variant hooks ----
  function _defaultVmId() internal pure virtual returns (bytes32);
  function _createVmCalldata(bytes32 methods, bytes32 id, bytes32 senderVmId, bytes32 vmId, address key)
    internal
    view
    virtual
    returns (bytes memory);

  // ---- views for the invariants ----
  function trackedLength() external view returns (uint256) {
    return tracked.length;
  }

  function trackedAt(uint256 i) external view returns (bytes32) {
    return tracked[i];
  }

  // =========================================================================
  // Actions
  // =========================================================================

  /// @notice Create a DID as one of two EOA owners.
  function createDid(uint256 seed) external {
    totalCalls++;
    _newDid(seed);
  }

  /// @notice Create a pending VM bound to one of 3 EOAs or 3 contracts.
  function createPendingVm(uint256 didSeed, uint256 keySeed) external {
    totalCalls++;
    if (dids.length == 0) _newDid(didSeed);
    if (dids.length == 0) return;
    _newPendingVm(didSeed % dids.length, _key(keySeed));
  }

  /// @notice An EOA calls validateVm directly. One wrong caller and then the bound address (when it is an EOA).
  function validateAsEoa(uint256 posSeed, uint256 callerSeed, uint256 expSeed) external {
    totalCalls++;
    bytes32 pos = _pickBoundToEoaOrCreate(posSeed);
    if (pos == bytes32(0)) return;
    address bound = ghost_boundTo[pos];
    uint256 exp = expSeed % 2 == 0 ? 0 : block.timestamp + 1 + (expSeed % 10 days);

    address[5] memory others = [owners[0], owners[1], stranger, eoaKeys[0], eoaKeys[1]];
    address wrong = others[callerSeed % 5];
    if (wrong == bound) wrong = makeAddr("never-a-key");
    _eoaValidate(pos, wrong, exp);
    // the right caller second, or a second wrong one when the VM is not bound to an EOA
    _eoaValidate(pos, callerSeed % 3 == 0 ? wrong : bound, exp);
  }

  /// @notice A contract key validates a VM: its own (usually) or another VM (the manager must refuse).
  function validateAsContract(uint256 posSeed, uint256 contractSeed) external {
    totalCalls++;
    address c = contractKeys[contractSeed % 3];
    bytes32 pos = posSeed % 4 == 0 ? _anyTracked(posSeed) : _pickBoundToOrCreate(c, posSeed);
    if (pos == bytes32(0)) return;
    _contractValidate(c, pos);
  }

  /// @notice Drive a contract into one of the 7 guarded writes with valid-looking arguments.
  function driveGuardedWrite(uint256 contractSeed, uint256 callSeed) external {
    totalCalls++;
    address c = contractKeys[contractSeed % 3];
    bytes32 pos = _validatedByOrCreate(c, contractSeed);
    if (pos == bytes32(0)) return;
    VmRef memory r = vmRefs[pos];
    DidRef memory d = dids[r.didIndex];
    bytes32 dv = _defaultVmId();
    uint256 which = callSeed % 7;
    bytes memory data;
    if (which == 0) {
      data = abi.encodeCall(IDidWriteOps.createDid, (d.methods, keccak256(abi.encode("cd", nonce++)), bytes32(0)));
    } else if (which == 1) {
      data = _createVmCalldata(d.methods, d.id, r.vmId, keccak256(abi.encode("cv", nonce++)), eoaKeys[0]);
    } else if (which == 2) {
      data = abi.encodeCall(IDidWriteOps.expireVm, (d.methods, d.id, r.vmId, d.id, dv));
    } else if (which == 3) {
      data = abi.encodeCall(IDidWriteOps.deactivateDid, (d.methods, d.id, r.vmId, d.id));
    } else if (which == 4) {
      data = abi.encodeCall(IDidWriteOps.reactivateDid, (d.methods, d.id, r.vmId, d.id));
    } else if (which == 5) {
      data = abi.encodeCall(IDidWriteOps.updateController, (d.methods, d.id, r.vmId, d.id, d.id, r.vmId, 0));
    } else {
      data = abi.encodeCall(
        IDidWriteOps.updateService, (d.methods, d.id, r.vmId, d.id, bytes32("svc"), bytes("t"), bytes("e"))
      );
    }
    contractWriteAttempts++;
    if (_exec(c, data)) ghost_guardedWriteSuccessFromContract++;
  }

  /// @notice The DID owner expires one of the tracked VMs.
  function expireRandomVm(uint256 posSeed) external {
    totalCalls++;
    bytes32 pos = _anyTracked(posSeed);
    if (pos == bytes32(0)) return;
    VmRef memory r = vmRefs[pos];
    DidRef memory d = dids[r.didIndex];
    vm.prank(d.owner, d.owner);
    MGR.call(abi.encodeCall(IDidWriteOps.expireVm, (d.methods, d.id, _defaultVmId(), d.id, r.vmId)));
  }

  // =========================================================================
  // Internals
  // =========================================================================

  function _key(uint256 seed) internal view returns (address) {
    uint256 i = seed % 6;
    return i < 3 ? eoaKeys[i] : contractKeys[i - 3];
  }

  function _isContractKey(address a) internal view returns (bool) {
    return a == contractKeys[0] || a == contractKeys[1] || a == contractKeys[2];
  }

  function _newDid(uint256 seed) internal returns (bool) {
    address o = owners[seed % 2];
    vm.recordLogs();
    vm.prank(o, o);
    (bool ok,) = MGR.call(
      abi.encodeCall(
        IDidWriteOps.createDid, (Fixtures.EMPTY_DID_METHODS, keccak256(abi.encode("did", nonce++)), bytes32(0))
      )
    );
    Vm.Log[] memory e = vm.getRecordedLogs();
    if (!ok || e.length < 3) return false;
    dids.push(DidRef({ methods: DEFAULT_DID_METHODS, id: e[2].topics[1], owner: o }));
    return true;
  }

  function _newPendingVm(uint256 didIndex, address key) internal returns (bytes32 pos) {
    DidRef memory d = dids[didIndex];
    bytes32 vmId = keccak256(abi.encode("vm", nonce++));
    vm.recordLogs();
    vm.prank(d.owner, d.owner);
    (bool ok,) = MGR.call(_createVmCalldata(d.methods, d.id, _defaultVmId(), vmId, key));
    Vm.Log[] memory e = vm.getRecordedLogs();
    if (!ok || e.length < 1) return bytes32(0);
    pos = bytes32(e[0].data);
    ghost_boundTo[pos] = key;
    vmRefs[pos] = VmRef({ didIndex: didIndex, vmId: vmId });
    tracked.push(pos);
  }

  function _anyTracked(uint256 seed) internal view returns (bytes32) {
    if (tracked.length == 0) return bytes32(0);
    return tracked[seed % tracked.length];
  }

  /// @dev A tracked VM bound to an EOA, or a new one when there is none.
  function _pickBoundToEoaOrCreate(uint256 seed) internal returns (bytes32) {
    uint256 n = tracked.length;
    for (uint256 i; i < n; i++) {
      bytes32 p = tracked[(seed % n + i) % n];
      if (!_isContractKey(ghost_boundTo[p])) return p;
    }
    return _createBound(seed, eoaKeys[seed % 3]);
  }

  function _pickBoundToOrCreate(address key, uint256 seed) internal returns (bytes32) {
    uint256 n = tracked.length;
    for (uint256 i; i < n; i++) {
      bytes32 p = tracked[(seed % n + i) % n];
      if (ghost_boundTo[p] == key) return p;
    }
    return _createBound(seed, key);
  }

  /// @dev A tracked VM bound to key and validated by key, or a new one validated now.
  function _validatedByOrCreate(address key, uint256 seed) internal returns (bytes32) {
    uint256 n = tracked.length;
    for (uint256 i; i < n; i++) {
      bytes32 p = tracked[(seed % n + i) % n];
      if (ghost_boundTo[p] == key && ghost_validatedBy[p] == key) return p;
    }
    bytes32 pos = _createBound(seed, key);
    if (pos == bytes32(0)) return bytes32(0);
    _contractValidate(key, pos);
    return ghost_validatedBy[pos] == key ? pos : bytes32(0);
  }

  function _createBound(uint256 seed, address key) internal returns (bytes32) {
    if (dids.length == 0 || seed % 3 == 0) _newDid(seed);
    if (dids.length == 0) return bytes32(0);
    return _newPendingVm(seed % dids.length, key);
  }

  function _eoaValidate(bytes32 pos, address caller, uint256 exp) internal {
    VmRef memory r = vmRefs[pos];
    DidRef memory d = dids[r.didIndex];
    (bool okRead, bytes memory ret) =
      MGR.staticcall(abi.encodeCall(IDidReadOps.getExpiration, (d.methods, d.id, r.vmId)));
    if (!okRead) return;
    bool expected = caller == ghost_boundTo[pos] && abi.decode(ret, (uint256)) == 0;
    if (caller == ghost_boundTo[pos]) eoaRightAttempts++;
    else eoaWrongAttempts++;

    vm.prank(caller, caller);
    (bool ok,) = MGR.call(abi.encodeCall(IDidWriteOps.validateVm, (pos, exp)));
    if (ok) ghost_validatedBy[pos] = caller;
    if (ok != expected) ghost_eoaMismatch++;
  }

  function _contractValidate(address c, bytes32 pos) internal {
    contractValidationAttempts++;
    bool ok;
    if (c == contractKeys[2]) {
      ok = _exec(c, abi.encodeCall(IDidWriteOps.validateVm, (pos, 0)));
    } else {
      (ok,) = c.call(abi.encodeCall(ReferenceIssuer.validate, (pos)));
    }
    if (ok) {
      ghost_validatedBy[pos] = c;
      contractValidationSuccesses++;
    }
  }

  /// @dev Makes contract c send data to the manager. The seen msg.sender is c.
  function _exec(address c, bytes memory data) internal returns (bool ok) {
    if (c == contractKeys[2]) vm.prank(stranger, stranger);
    (ok,) = c.call(abi.encodeCall(OpenCaller.exec, (MGR, data)));
  }
}

contract ContractKeyHandler is ContractKeyHandlerBase {
  constructor(address manager) ContractKeyHandlerBase(manager) { }

  function _defaultVmId() internal pure override returns (bytes32) {
    return DEFAULT_VM_ID;
  }

  function _createVmCalldata(bytes32 methods, bytes32 id, bytes32 senderVmId, bytes32 vmId, address key)
    internal
    pure
    override
    returns (bytes memory)
  {
    return abi.encodeCall(
      IDidManagerFull.createVm,
      (CreateVmCommand({
          methods: methods,
          senderId: id,
          senderVmId: senderVmId,
          targetId: id,
          vmId: vmId,
          type_: Fixtures.defaultVmType(),
          publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase(),
          blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
          ethereumAddress: key,
          relationships: R_ALL,
          expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
        }))
    );
  }
}

contract ContractKeyHandlerNative is ContractKeyHandlerBase {
  constructor(address manager) ContractKeyHandlerBase(manager) { }

  function _defaultVmId() internal pure override returns (bytes32) {
    return DEFAULT_VM_ID_NATIVE;
  }

  function _createVmCalldata(bytes32 methods, bytes32 id, bytes32 senderVmId, bytes32 vmId, address key)
    internal
    pure
    override
    returns (bytes memory)
  {
    return abi.encodeCall(
      IDidManagerNative.createVm,
      (NativeCreateVmCommand({
          methods: methods,
          senderId: id,
          senderVmId: senderVmId,
          targetId: id,
          vmId: vmId,
          ethereumAddress: key,
          relationships: R_ALL,
          publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase()
        }))
    );
  }
}

/**
 * @title ContractKeyInvariants
 * @notice Four properties of contract-held verification methods, on both variants.
 */
abstract contract ContractKeyInvariantsCases is StdInvariant, Test {
  ContractKeyHandlerBase internal handler;

  /// @dev Below this many calls the reach counters can legitimately still be zero.
  uint256 internal constant REACH_AFTER_CALLS = 96;

  function _targetHandler() internal {
    targetContract(address(handler));
    bytes4[] memory selectors = new bytes4[](6);
    selectors[0] = ContractKeyHandlerBase.createDid.selector;
    selectors[1] = ContractKeyHandlerBase.createPendingVm.selector;
    selectors[2] = ContractKeyHandlerBase.validateAsEoa.selector;
    selectors[3] = ContractKeyHandlerBase.validateAsContract.selector;
    selectors[4] = ContractKeyHandlerBase.driveGuardedWrite.selector;
    selectors[5] = ContractKeyHandlerBase.expireRandomVm.selector;
    targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
  }

  /// @notice A VM that was validated, was validated by the address it is bound to.
  function invariant_ValidatedVmWasValidatedByItsOwnAddress() public view {
    uint256 n = handler.trackedLength();
    for (uint256 i; i < n; i++) {
      bytes32 pos = handler.trackedAt(i);
      address by = handler.ghost_validatedBy(pos);
      if (by != address(0)) assertEq(by, handler.ghost_boundTo(pos), "validated by an address it is not bound to");
    }
  }

  /// @notice The EOA path is unchanged: it succeeds exactly when the caller is the bound address and the VM is pending.
  function invariant_EoaValidationFollowsTheRule() public view {
    assertEq(handler.ghost_eoaMismatch(), 0, "EOA validation disagreed with the rule");
  }

  /// @notice No guarded write ever succeeds when its msg.sender is a contract.
  function invariant_NoGuardedWriteSucceedsFromAContract() public view {
    assertEq(handler.ghost_guardedWriteSuccessFromContract(), 0, "a contract completed a guarded write");
  }

  /// @notice A handler that never reaches the paths proves nothing.
  function invariant_HandlerReachedContractPaths() public view {
    if (handler.totalCalls() < REACH_AFTER_CALLS) return;
    assertGt(handler.contractValidationAttempts(), 0, "no contract validation attempted");
    assertGt(handler.contractWriteAttempts(), 0, "no contract guarded write attempted");
    assertGt(handler.eoaRightAttempts(), 0, "no EOA validation by the bound address attempted");
    assertGt(handler.eoaWrongAttempts(), 0, "no EOA validation by a wrong caller attempted");
  }
}

/// forge-config: ci.invariant.depth = 128
contract ContractKeyInvariantsTest is ContractKeyInvariantsCases, TestBase {
  function setUp() public {
    _deployDidManager();
    handler = new ContractKeyHandler(address(didManager));
    _targetHandler();
  }
}

/// forge-config: ci.invariant.depth = 128
contract ContractKeyInvariantsNativeTest is ContractKeyInvariantsCases, TestBaseNative {
  function setUp() public {
    _deployDidManagerNative();
    handler = new ContractKeyHandlerNative(address(didManagerNative));
    _targetHandler();
  }
}
