// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { CasesBase, ContractVmFullBase, ContractVmNativeBase, IManager } from "@test/unit/ContractVm.unit.t.sol";
import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";
import { OpenCaller } from "@test/mocks/MockContractKeys.sol";
import { ReactivationBase } from "@test/unit/Reactivation.unit.t.sol";

/**
 * @title ContractVmFuzz
 * @notice Property: a pending verification method becomes valid for exactly one caller, the address it is bound to.
 * @dev Runs on both variants. Two tests: the first sends the call from an arbitrary EOA (two-argument
 * prank); the second drives validateVm through an OpenCaller contract (msg.sender is the contract,
 * tx.origin an arbitrary EOA), so a wrong contract caller and a bound contract caller are both covered.
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

  /// @notice A contract caller is judged by its own address, not by the EOA behind it.
  function testFuzz_ValidateVm_Should_BindToContractCaller_When_DrivenThroughOpenCaller(
    address driver,
    uint88 expiration
  ) public {
    vm.assume(driver != address(0));
    OpenCaller opener = new OpenCaller();
    vm.assume(driver != address(opener));
    address k = makeAddr("bound-key");

    // A VM bound to another address: the contract caller is rejected whoever drives it.
    (bytes32 m, bytes32 id) = _newDid(owner, bytes32("fz-c1"));
    bytes32 pos = _newVm(owner, m, id, VM_T, k, R_ASSERTION);
    vm.prank(driver, driver);
    vm.expectRevert(INVALID_SIGNATURE);
    opener.exec(_mgr(), abi.encodeCall(IDidWriteOps.validateVm, (pos, uint256(expiration))));
    assertEq(IManager(_mgr()).getExpiration(m, id, VM_T), 0, "VM stays pending after a wrong contract caller");

    // A VM bound to the contract: it validates through the contract.
    (bytes32 m2, bytes32 id2) = _newDid(owner, bytes32("fz-c2"));
    bytes32 pos2 = _newVm(owner, m2, id2, VM_T, address(opener), R_ASSERTION);
    vm.prank(driver, driver);
    opener.exec(_mgr(), abi.encodeCall(IDidWriteOps.validateVm, (pos2, uint256(expiration))));
    uint256 expected = expiration == 0 ? block.timestamp + 365 days : uint256(expiration);
    assertEq(IManager(_mgr()).getExpiration(m2, id2, VM_T), expected, "the bound contract validated the VM");
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
