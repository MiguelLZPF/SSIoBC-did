// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { W3CResolverBase } from "@src/W3CResolverBase.sol";
import { W3CVerificationMethod, W3CDidInput } from "@types/W3CTypes.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { VerificationMethod } from "@types/VmTypes.sol";
import { W3CResolverUtils } from "@src/W3CResolverUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title W3CResolver
/// @author Miguel Gomez Carpena
/// @notice W3C DID document resolver (full variant)
contract W3CResolver is W3CResolverBase {
  IDidManagerFull private _didManagerFull;

  constructor(IDidManagerFull didManager) {
    _didReadOps = didManager;
    _didManagerFull = didManager;
  }

  function resolveVm(W3CDidInput memory didInput, bytes32 vmId) public view returns (W3CVerificationMethod memory vm) {
    W3CResolverUtils.checkDidInput(didInput);
    return _toW3cVerificationMethod(
      _didManagerFull.getVm(didInput.methods, didInput.id, vmId, 0), W3CResolverUtils.formatDidString(didInput)
    );
  }

  // * Internal functions

  function _getAllVerificationMethods(W3CDidInput memory didInput, bool includeExpired, string memory didString)
    internal
    view
    override
    returns (W3CVerificationMethod[] memory vms, string[][] memory methods)
  {
    // * (0) Temporal variables creation
    string[][] memory methodsTemp = new string[][](5);
    uint8 maxLength = _didManagerFull.getVmListLength(didInput.methods, didInput.id);
    for (uint8 i = 0; i < 5; i++) {
      methodsTemp[i] = new string[](maxLength);
    }
    W3CVerificationMethod[] memory vmsTemp = new W3CVerificationMethod[](maxLength);
    uint8[] memory realLength = new uint8[](6);
    bytes memory didPrefix = W3CResolverUtils.formatDidPrefix(didInput);
    // * (1) Iterate over the VM list (0-based counter: a 1-based `i <= maxLength` loop overflows uint8 at 255 VMs)
    for (uint8 i = 0; i < maxLength; i++) {
      VerificationMethod memory vm = _didManagerFull.getVm(didInput.methods, didInput.id, bytes32(0), i + 1);
      if (includeExpired || vm.expiration > block.timestamp) {
        vmsTemp[realLength[0]] = _toW3cVerificationMethod(vm, didString);
        realLength[0]++;
        string memory methodString = W3CResolverUtils.formatDidWithFragment(didPrefix, vm.id);
        if (vm.relationships & 0x01 == 0x01) {
          methodsTemp[0][realLength[1]] = methodString;
          realLength[1]++;
        }
        if (vm.relationships & 0x02 == 0x02) {
          methodsTemp[1][realLength[2]] = methodString;
          realLength[2]++;
        }
        if (vm.relationships & 0x04 == 0x04) {
          methodsTemp[2][realLength[3]] = methodString;
          realLength[3]++;
        }
        if (vm.relationships & 0x08 == 0x08) {
          methodsTemp[3][realLength[4]] = methodString;
          realLength[4]++;
        }
        if (vm.relationships & 0x10 == 0x10) {
          methodsTemp[4][realLength[5]] = methodString;
          realLength[5]++;
        }
      }
    }
    // * (2) Shrink the temporary arrays in place and return them
    vms = vmsTemp;
    methods = methodsTemp;
    assembly ("memory-safe") {
      // Safe: only lowers each length to the count actually filled (never above the allocation), the tail is simply
      // left unused.
      mstore(vms, mload(add(realLength, 0x20)))
      for { let i := 0 } lt(i, 5) { i := add(i, 1) } {
        mstore(mload(add(add(methods, 0x20), mul(i, 0x20))), mload(add(realLength, mul(add(i, 2), 0x20))))
      }
    }

    return (vms, methods);
  }

  function _toW3cVerificationMethod(VerificationMethod memory vm, string memory controller)
    internal
    pure
    returns (W3CVerificationMethod memory w3cVm)
  {
    return W3CVerificationMethod({
      id: string(W3CResolverUtils.trimBytes(abi.encodePacked(vm.id))),
      type_: string(W3CResolverUtils.trimBytes(abi.encodePacked(vm.type_))),
      controller: controller,
      publicKeyMultibase: string(vm.publicKeyMultibase),
      blockchainAccountId: string(vm.blockchainAccountId),
      ethereumAddress: Strings.toHexString(vm.ethereumAddress),
      expiration: uint256(vm.expiration) * 1000
    });
  }
}
