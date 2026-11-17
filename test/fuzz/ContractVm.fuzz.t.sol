// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { CasesBase, ContractVmFullBase, ContractVmNativeBase, IManager } from "@test/unit/ContractVm.unit.t.sol";
import { ReactivationBase } from "@test/unit/Reactivation.unit.t.sol";

/**
 * @title ContractVmFuzz
 * @notice Property: a pending verification method becomes valid for exactly one caller, the address it is bound to.
 * @dev Runs on both variants. The caller is an arbitrary address; the manager only compares msg.sender
 * with the bound address, so the same property covers an EOA and a contract.
 */
abstract contract ContractVmFuzzCases is CasesBase {
  /// @notice Any caller other than the bound address reverts InvalidSignature; the bound address succeeds.
  function testFuzz_ValidateVm_Should_OnlySucceed_When_CallerIsVmAddress(address caller, uint88 expiration) public {
    address k = makeAddr("bound-key");
    vm.assume(caller != k && caller != address(0));

    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("fz-did"));
    bytes32 pos = _newVm(owner, m, id, VM_T, k, R_ASSERTION);

    vm.prank(caller, caller);
    vm.expectRevert(INVALID_SIGNATURE);
    IManager(_mgr()).validateVm(pos, expiration);
    assertEq(IManager(_mgr()).getExpiration(m, id, VM_T), 0, "VM stays pending after a wrong caller");

    vm.prank(k, k);
    IManager(_mgr()).validateVm(pos, expiration);
    uint256 expected = expiration == 0 ? block.timestamp + 365 days : uint256(expiration);
    assertEq(IManager(_mgr()).getExpiration(m, id, VM_T), expected, "the bound address validated the VM");
  }
}

/// @notice Reactivating needs a live authentication key: no other caller, and no owner past the key lifetime.
abstract contract ReactivationFuzzCases is ReactivationBase {
  function testFuzz_ReactivateDid_Should_Revert_When_CallerHasNoLiveAuthenticationKey(address caller, uint32 wait)
    public
  {
    vm.assume(caller != owner && caller != address(0));
    (bytes32 m, bytes32 t) = _newDid(owner, bytes32("rx-fz"));
    _addKey(m, t, K_VM, k, R_AUTH, true);
    vm.prank(owner, owner);
    IManager(_mgr()).expireVm(m, t, _defaultVmId(), t, K_VM);
    uint256 defaultVmExpiry = _vmExp(m, t, _defaultVmId());
    _deactivate(owner, m, t, _defaultVmId(), t);
    vm.warp(block.timestamp + uint256(wait));
    // A VM is live while expiration > block.timestamp; _isAuthenticated reverts VmAlreadyExpired otherwise,
    // and returns false (NotAuthenticatedAsSenderId) for a live key that is not the caller's.
    bool defaultVmLive = defaultVmExpiry > block.timestamp;

    // K_VM was expired explicitly: VmAlreadyExpired for any caller.
    vm.prank(caller, caller);
    vm.expectRevert(VM_ALREADY_EXPIRED);
    IManager(_mgr()).reactivateDid(m, t, K_VM, t);

    vm.prank(caller, caller);
    vm.expectRevert(defaultVmLive ? NOT_AUTHENTICATED : VM_ALREADY_EXPIRED);
    IManager(_mgr()).reactivateDid(m, t, _defaultVmId(), t);
    assertEq(_exp(m, t), 0, "DID stays deactivated");

    if (!defaultVmLive) {
      vm.expectRevert(VM_ALREADY_EXPIRED);
      _reactivate(owner, m, t, _defaultVmId(), t);
      assertEq(_exp(m, t), 0, "owner past the key lifetime is rejected");
    }
  }
}

contract ContractVmFuzzTest is ContractVmFuzzCases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
  }
}

contract ReactivationFuzzTest is ReactivationFuzzCases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
  }
}

contract ReactivationNativeFuzzTest is ReactivationFuzzCases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
  }
}

contract ContractVmNativeFuzzTest is ContractVmFuzzCases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
  }
}
