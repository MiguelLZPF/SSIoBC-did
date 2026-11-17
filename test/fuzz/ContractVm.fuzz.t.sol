// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { CasesBase, ContractVmFullBase, ContractVmNativeBase, IManager } from "@test/unit/ContractVm.unit.t.sol";

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

contract ContractVmFuzzTest is ContractVmFuzzCases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
  }
}

contract ContractVmNativeFuzzTest is ContractVmFuzzCases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
  }
}
