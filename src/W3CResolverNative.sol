// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { W3CResolverBase } from "@src/W3CResolverBase.sol";
import { W3CVerificationMethod, W3CDidInput } from "@types/W3CTypes.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { VerificationMethod } from "@types/VmTypesNative.sol";
import { W3CResolverUtils } from "@src/W3CResolverUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// ! This Contract is NOT necessary, only adds ONchain DID resolution
/**
 * @title W3CResolverNative
 * @author Miguel Gomez Carpena
 * @dev Resolves Ethereum-native DIDs into W3C-compliant DID documents.
 * Derives W3C fields (type_, publicKeyMultibase, blockchainAccountId) at resolution time
 * from the 1-slot native VerificationMethod storage.
 */
contract W3CResolverNative is W3CResolverBase {
  /// @dev Fixed W3C type for all Ethereum-native VMs
  string private constant NATIVE_VM_TYPE = "EcdsaSecp256k1VerificationKey2019";

  IDidManagerNative private _didManagerNative;

  constructor(IDidManagerNative didManager) {
    _didReadOps = didManager;
    _didManagerNative = didManager;
  }

  function resolveVm(W3CDidInput memory didInput, bytes32 vmId) public view returns (W3CVerificationMethod memory vm) {
    W3CResolverUtils.checkDidInput(didInput);
    VerificationMethod memory nativeVm = _didManagerNative.getVm(didInput.methods, didInput.id, vmId, 0);
    return _toW3cVerificationMethod(nativeVm, vmId, didInput, W3CResolverUtils.formatDidString(didInput));
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
    uint8 maxLength = _didManagerNative.getVmListLength(didInput.methods, didInput.id);
    for (uint8 i = 0; i < 5; i++) {
      methodsTemp[i] = new string[](maxLength);
    }
    W3CVerificationMethod[] memory vmsTemp = new W3CVerificationMethod[](maxLength);
    uint8[] memory realLength = new uint8[](6);
    bytes memory didPrefix = W3CResolverUtils.formatDidPrefix(didInput);

    // * (1) Iterate over the VM list (1-based positions)
    for (uint8 i = 1; i <= maxLength; i++) {
      VerificationMethod memory nativeVm = _didManagerNative.getVm(didInput.methods, didInput.id, bytes32(0), i);

      if (includeExpired || nativeVm.expiration > block.timestamp) {
        // Native VMs don't store ID in struct; retrieve it via position, only for VMs that are kept
        bytes32 vmId = _didManagerNative.getVmIdAtPosition(didInput.methods, didInput.id, i);
        vmsTemp[realLength[0]] = _toW3cVerificationMethod(nativeVm, vmId, didInput, didString);
        realLength[0]++;
        string memory methodString = W3CResolverUtils.formatDidWithFragment(didPrefix, vmId);
        if (nativeVm.relationships & 0x01 == 0x01) {
          methodsTemp[0][realLength[1]] = methodString;
          realLength[1]++;
        }
        if (nativeVm.relationships & 0x02 == 0x02) {
          methodsTemp[1][realLength[2]] = methodString;
          realLength[2]++;
        }
        if (nativeVm.relationships & 0x04 == 0x04) {
          methodsTemp[2][realLength[3]] = methodString;
          realLength[3]++;
        }
        if (nativeVm.relationships & 0x08 == 0x08) {
          methodsTemp[3][realLength[4]] = methodString;
          realLength[4]++;
        }
        if (nativeVm.relationships & 0x10 == 0x10) {
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

  /**
   * @dev Converts a native VerificationMethod to W3C format by deriving fields at resolution time.
   * - type_: Always "EcdsaSecp256k1VerificationKey2019" (Ethereum-native)
   * - publicKeyMultibase: Read from storage for keyAgreement VMs, empty otherwise
   * - blockchainAccountId: Derived as CAIP-10 from ethereumAddress and block.chainid
   */
  function _toW3cVerificationMethod(
    VerificationMethod memory nativeVm,
    bytes32 vmId,
    W3CDidInput memory didInput,
    string memory controller
  ) internal view returns (W3CVerificationMethod memory w3cVm) {
    string memory ethereumAddress = Strings.toHexString(nativeVm.ethereumAddress);
    string memory blockchainAccountId;
    if (nativeVm.ethereumAddress != address(0)) {
      blockchainAccountId = string(abi.encodePacked("eip155:", Strings.toString(block.chainid), ":", ethereumAddress));
    }

    return W3CVerificationMethod({
      id: string(W3CResolverUtils.trimBytes(abi.encodePacked(vmId))),
      type_: NATIVE_VM_TYPE,
      controller: controller,
      publicKeyMultibase: string(_didManagerNative.getVmPublicKeyMultibase(didInput.methods, didInput.id, vmId)),
      blockchainAccountId: blockchainAccountId,
      ethereumAddress: ethereumAddress,
      expiration: uint256(nativeVm.expiration) * 1000
    });
  }
}
