// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { HashUtils } from "@src/HashUtils.sol";
import { CasesBase, ContractVmFullBase, ContractVmNativeBase, IManager } from "@test/unit/ContractVm.unit.t.sol";

/**
 * @title ReactivationCases
 * @notice reactivateDid has one authorization rule: a live authentication key (D5 = B, D6 = A).
 * @dev Runs on both variants. `o` owns DID T, `k` is a second EOA, `p` owns DID C.
 */
abstract contract ReactivationBase is CasesBase {
  event DidReactivated(bytes32 indexed targetDidHash);

  bytes4 internal constant NOT_AUTHENTICATED = bytes4(keccak256("NotAuthenticatedAsSenderId()"));
  bytes4 internal constant NOT_A_CONTROLLER = bytes4(keccak256("NotAControllerForTargetId()"));

  bytes1 internal constant R_AUTH = 0x01;
  uint256 internal constant DID_PERIOD = 126144000;
  bytes32 internal constant K_VM = bytes32("vm-k");

  address internal k = makeAddr("second-key");
  address internal p = makeAddr("controller-owner");

  function _deactivate(address who, bytes32 m, bytes32 sender, bytes32 senderVm, bytes32 target) internal {
    vm.prank(who, who);
    IManager(_mgr()).deactivateDid(m, sender, senderVm, target);
  }

  function _reactivate(address who, bytes32 m, bytes32 sender, bytes32 senderVm, bytes32 target) internal {
    vm.prank(who, who);
    IManager(_mgr()).reactivateDid(m, sender, senderVm, target);
  }

  function _expectReactivated(bytes32 m, bytes32 target) internal {
    vm.expectEmit(true, false, false, false, _mgr());
    emit DidReactivated(HashUtils.calculateIdHash(m, target));
  }

  function _vmExp(bytes32 m, bytes32 id, bytes32 vmId) internal view returns (uint256) {
    return IManager(_mgr()).getExpiration(m, id, vmId);
  }

  function _exp(bytes32 m, bytes32 id) internal view returns (uint256) {
    return IManager(_mgr()).getExpiration(m, id, 0);
  }

  /// @dev Adds a second key for `key` to the DID (owner call) and, if asked, validates it as `key`.
  function _addKey(bytes32 m, bytes32 id, bytes32 vmId, address key, bytes1 rel, bool validate) internal {
    bytes32 pos = _newVm(owner, m, id, vmId, key, rel);
    if (validate) {
      vm.prank(key, key);
      IManager(_mgr()).validateVm(pos, 0);
    }
  }

  /// @dev DID C (owned by p) becomes the single controller of T, which o owns.
  function _makeControlled(bytes32 m, bytes32 t, bytes32 c) internal {
    vm.prank(owner, owner);
    IManager(_mgr()).updateController(m, t, _defaultVmId(), t, c, bytes32(0), 0);
  }
}

/// @dev The unit cases; the fuzz suites inherit only ReactivationBase, so these do not run again there.
abstract contract ReactivationCases is ReactivationBase {
  // 1
  function test_RevertWhen_ReactivateDid_SelfWithExpiredKey() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx1"));
    _addKey(m, t, K_VM, k, R_AUTH, true);
    vm.prank(owner, owner);
    IManager(_mgr()).expireVm(m, t, _defaultVmId(), t, K_VM);
    _deactivate(owner, m, t, _defaultVmId(), t);

    vm.expectRevert(VM_ALREADY_EXPIRED);
    _reactivate(k, m, t, K_VM, t);
    assertEq(_exp(m, t), 0, "DID stays deactivated");
  }

  // 2
  function test_RevertWhen_ReactivateDid_SelfWithNeverValidatedKey() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx2"));
    _addKey(m, t, K_VM, k, R_AUTH, false);
    _deactivate(owner, m, t, _defaultVmId(), t);

    vm.expectRevert(VM_ALREADY_EXPIRED);
    _reactivate(k, m, t, K_VM, t);
    assertEq(_exp(m, t), 0, "DID stays deactivated");
  }

  // 3 (pins D5 = B)
  function test_ReactivateDid_Should_Succeed_When_OwnLiveKeyReactivatesAfterControllerDeactivation() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx3"));
    (, bytes32 c) = _newDid(p, bytes32("rx3-c"));
    _makeControlled(m, t, c);
    _deactivate(p, m, c, _defaultVmId(), t);
    assertEq(_exp(m, t), 0, "controller deactivated T");

    _expectReactivated(m, t);
    _reactivate(owner, m, t, _defaultVmId(), t);
    assertEq(_exp(m, t), block.timestamp + DID_PERIOD, "own live key reactivated T");

    vm.expectRevert(NOT_A_CONTROLLER);
    _deactivate(owner, m, t, _defaultVmId(), t);
  }

  // 4
  function test_RevertWhen_ReactivateDid_SelfAfterKeyLifetime() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx4"));
    _deactivate(owner, m, t, _defaultVmId(), t);
    vm.warp(block.timestamp + 366 days);

    vm.expectRevert(VM_ALREADY_EXPIRED);
    _reactivate(owner, m, t, _defaultVmId(), t);
    assertEq(_exp(m, t), 0, "DID stays deactivated");
  }

  // 5
  function test_ReactivateDid_Should_Succeed_When_OwnerKeyIsLive() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx5"));
    _deactivate(owner, m, t, _defaultVmId(), t);

    _expectReactivated(m, t);
    _reactivate(owner, m, t, _defaultVmId(), t);
    assertEq(_exp(m, t), block.timestamp + DID_PERIOD, "reactivated for the full period");
    assertTrue(_auth(m, t, _defaultVmId(), R_AUTH, owner), "owner key authorizes again");
  }

  // 6
  function test_ReactivateDid_Should_Succeed_When_ControllerReactivatesControlledDid() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx6"));
    (, bytes32 c) = _newDid(p, bytes32("rx6-c"));
    (, bytes32 x) = _newDid(stranger, bytes32("rx6-x"));
    _makeControlled(m, t, c);
    _deactivate(p, m, c, _defaultVmId(), t);

    vm.expectRevert(NOT_A_CONTROLLER);
    _reactivate(stranger, m, x, _defaultVmId(), t);
    assertEq(_exp(m, t), 0, "a non-controller cannot reactivate");

    _expectReactivated(m, t);
    _reactivate(p, m, c, _defaultVmId(), t);
    assertEq(_exp(m, t), block.timestamp + DID_PERIOD, "controller reactivated T");
  }

  // 6b
  function test_RevertWhen_ReactivateDid_SelfAfterControllerDeactivation_WithExpiredKey() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx6b"));
    (, bytes32 c) = _newDid(p, bytes32("rx6b-c"));
    _makeControlled(m, t, c);
    _deactivate(p, m, c, _defaultVmId(), t);
    vm.warp(block.timestamp + 366 days);

    vm.expectRevert(VM_ALREADY_EXPIRED);
    _reactivate(owner, m, t, _defaultVmId(), t);
    assertEq(_exp(m, t), 0, "DID stays deactivated");
  }

  // 7
  function test_RevertWhen_ReactivateDid_SelfWithNonAuthenticationKey() public {
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx7"));
    _addKey(m, t, K_VM, k, R_ASSERTION, true);
    _deactivate(owner, m, t, _defaultVmId(), t);

    vm.expectRevert(NOT_AUTHENTICATED);
    _reactivate(k, m, t, K_VM, t);
    assertEq(_exp(m, t), 0, "DID stays deactivated");
  }
}

contract ReactivationUnitTest is ReactivationCases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
  }
}

contract ReactivationNativeUnitTest is ReactivationCases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
  }
}
