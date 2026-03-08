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
    return _toW3cVerificationMethod(nativeVm, vmId, didInput);
  }

  // * Internal functions

  function _getAllVerificationMethods(W3CDidInput memory didInput, bool includeExpired)
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

    // * (1) Iterate over the VM list (1-based positions)
    for (uint8 i = 1; i <= maxLength; i++) {
      // Native VMs don't store ID in struct; retrieve it via position
      bytes32 vmId = _didManagerNative.getVmIdAtPosition(didInput.methods, didInput.id, i);
      VerificationMethod memory nativeVm = _didManagerNative.getVm(didInput.methods, didInput.id, bytes32(0), i);

      if (includeExpired || (nativeVm.expiration != 0 && nativeVm.expiration > block.timestamp)) {
        vmsTemp[realLength[0]] = _toW3cVerificationMethod(nativeVm, vmId, didInput);
        realLength[0]++;
        string memory methodString =
          W3CResolverUtils.formatDidString(W3CDidInput({ methods: didInput.methods, id: didInput.id, fragment: vmId }));
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

    // * (2) Create the final arrays
    vms = new W3CVerificationMethod[](realLength[0]);
    for (uint8 i = 0; i < realLength[0]; i++) {
      vms[i] = vmsTemp[i];
    }
    methods = new string[][](5);
    methods[0] = new string[](realLength[1]);
    for (uint8 i = 0; i < realLength[1]; i++) {
      methods[0][i] = methodsTemp[0][i];
    }
    methods[1] = new string[](realLength[2]);
    for (uint8 i = 0; i < realLength[2]; i++) {
      methods[1][i] = methodsTemp[1][i];
    }
    methods[2] = new string[](realLength[3]);
    for (uint8 i = 0; i < realLength[3]; i++) {
      methods[2][i] = methodsTemp[2][i];
    }
    methods[3] = new string[](realLength[4]);
    for (uint8 i = 0; i < realLength[4]; i++) {
      methods[3][i] = methodsTemp[3][i];
    }
    methods[4] = new string[](realLength[5]);
    for (uint8 i = 0; i < realLength[5]; i++) {
      methods[4][i] = methodsTemp[4][i];
    }

    return (vms, methods);
  }

  /**
   * @dev Converts a native VerificationMethod to W3C format by deriving fields at resolution time.
   * - type_: Always "EcdsaSecp256k1VerificationKey2019" (Ethereum-native)
   * - publicKeyMultibase: Read from storage for keyAgreement VMs, empty otherwise
   * - blockchainAccountId: Derived as CAIP-10 from ethereumAddress and block.chainid
   */
  function _toW3cVerificationMethod(VerificationMethod memory nativeVm, bytes32 vmId, W3CDidInput memory didInput)
    internal
    view
    returns (W3CVerificationMethod memory w3cVm)
  {
    string memory blockchainAccountId = nativeVm.ethereumAddress != address(0)
      ? string(
        abi.encodePacked("eip155:", Strings.toString(block.chainid), ":", Strings.toHexString(nativeVm.ethereumAddress))
      )
      : "";

    return W3CVerificationMethod({
      id: string(W3CResolverUtils.trimBytes(abi.encodePacked(vmId))),
      type_: NATIVE_VM_TYPE,
      controller: W3CResolverUtils.formatDidString(didInput),
      publicKeyMultibase: string(_didManagerNative.getVmPublicKeyMultibase(didInput.methods, didInput.id, vmId)),
      blockchainAccountId: blockchainAccountId,
      ethereumAddress: Strings.toHexString(nativeVm.ethereumAddress),
      expiration: uint256(nativeVm.expiration) * 1000
    });
  }
}
