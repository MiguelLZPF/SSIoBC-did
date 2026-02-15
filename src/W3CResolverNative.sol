// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {
  IW3CResolver,
  W3CDidDocument,
  W3CVerificationMethod,
  W3CService,
  W3CDidInput
} from "./interfaces/IW3CResolver.sol";
import { IDidManagerNative } from "./interfaces/IDidManagerNative.sol";
import { VerificationMethod } from "@src/VMStorageNative.sol";
import { W3CResolverUtils } from "@src/W3CResolverUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// ! This Contract is NOT necessary, only adds ONchain DID resolution
/**
 * @title W3CResolverNative
 * @dev Resolves Ethereum-native DIDs into W3C-compliant DID documents.
 * Derives W3C fields (type_, publicKeyMultibase, blockchainAccountId) at resolution time
 * from the 1-slot native VerificationMethod storage.
 */
contract W3CResolverNative is IW3CResolver {
  string[] private DEFAULT_CONTEXT = ["https://www.w3.org/ns/did/v1"];

  /// @dev Fixed W3C type for all Ethereum-native VMs
  string private constant NATIVE_VM_TYPE = "EcdsaSecp256k1VerificationKey2019";

  IDidManagerNative internal _didManager;

  constructor(IDidManagerNative didManager) {
    _didManager = didManager;
  }

  function resolve(W3CDidInput memory didInput, bool includeExpired)
    external
    view
    returns (W3CDidDocument memory didDocument)
  {
    // * Get Verification Methods (with W3C field derivation)
    (W3CVerificationMethod[] memory vms, string[][] memory methods) =
      _getAllVerificationMethods(didInput, includeExpired);
    // * Get Services
    W3CService[] memory services = new W3CService[](_didManager.getServiceListLength(didInput.methods, didInput.id));
    for (uint8 i = 0; i < services.length; i++) {
      services[i] = W3CResolverUtils.toW3cService(
        _didManager.getService(
          didInput.methods,
          didInput.id,
          bytes32(0),
          i + 1 // service list starts at 1
        )
      );
    }

    // * Structure DID Document
    return W3CDidDocument({
      context: DEFAULT_CONTEXT,
      id: W3CResolverUtils.formatDidString(didInput),
      controller: W3CResolverUtils.toW3cController(
        _didManager.getControllerList(didInput.methods, didInput.id), didInput.methods
      ),
      verificationMethod: vms,
      authentication: methods[0],
      assertionMethod: methods[1],
      keyAgreement: methods[2],
      capabilityInvocation: methods[3],
      capabilityDelegation: methods[4],
      service: services,
      expiration: _didManager.getExpiration(didInput.methods, didInput.id, bytes32(0)) * 1000
    });
  }

  function resolveVm(W3CDidInput memory didInput, bytes32 vmId) public view returns (W3CVerificationMethod memory vm) {
    W3CResolverUtils.checkDidInput(didInput);
    VerificationMethod memory nativeVm = _didManager.getVm(didInput.methods, didInput.id, vmId, 0);
    return _toW3cVerificationMethod(nativeVm, vmId, didInput);
  }

  function resolveService(W3CDidInput memory didInput, bytes32 serviceId)
    public
    view
    returns (W3CService memory service)
  {
    W3CResolverUtils.checkDidInput(didInput);
    return W3CResolverUtils.toW3cService(_didManager.getService(didInput.methods, didInput.id, serviceId, 0));
  }

  // * Internal functions

  function _getAllVerificationMethods(W3CDidInput memory didInput, bool includeExpired)
    internal
    view
    returns (W3CVerificationMethod[] memory vms, string[][] memory methods)
  {
    // * (0) Temporal variables creation
    string[][] memory methodsTemp = new string[][](5);
    uint8 maxLength = _didManager.getVmListLength(didInput.methods, didInput.id);
    for (uint8 i = 0; i < 5; i++) {
      methodsTemp[i] = new string[](maxLength);
    }
    W3CVerificationMethod[] memory vmsTemp = new W3CVerificationMethod[](maxLength);
    uint8[] memory realLength = new uint8[](6);

    // * (1) Iterate over the VM list (1-based positions)
    for (uint8 i = 1; i <= maxLength; i++) {
      // Native VMs don't store ID in struct; retrieve it via position
      bytes32 vmId = _didManager.getVmIdAtPosition(didInput.methods, didInput.id, i);
      VerificationMethod memory nativeVm = _didManager.getVm(didInput.methods, didInput.id, bytes32(0), i);

      if (includeExpired || (nativeVm.expiration != 0 && nativeVm.expiration > block.timestamp)) {
        vmsTemp[realLength[0]] = _toW3cVerificationMethod(nativeVm, vmId, didInput);
        realLength[0]++;
        // Add the VM to the corresponding method array
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
   * @param nativeVm The native VerificationMethod (1 slot).
   * @param vmId The VM identifier (retrieved separately since native struct doesn't store it).
   * @param didInput The DID input for controller field.
   * @return w3cVm The W3C-formatted verification method.
   */
  function _toW3cVerificationMethod(VerificationMethod memory nativeVm, bytes32 vmId, W3CDidInput memory didInput)
    internal
    view
    returns (W3CVerificationMethod memory w3cVm)
  {
    // Derive CAIP-10 blockchainAccountId from ethereumAddress + chain ID
    string memory blockchainAccountId = nativeVm.ethereumAddress != address(0)
      ? string(
        abi.encodePacked("eip155:", Strings.toString(block.chainid), ":", Strings.toHexString(nativeVm.ethereumAddress))
      )
      : "";

    return W3CVerificationMethod({
      id: string(W3CResolverUtils.trimBytes(abi.encodePacked(vmId))),
      type_: NATIVE_VM_TYPE,
      controller: W3CResolverUtils.formatDidString(didInput),
      publicKeyMultibase: string(_didManager.getVmPublicKeyMultibase(didInput.methods, didInput.id, vmId)),
      blockchainAccountId: blockchainAccountId,
      ethereumAddress: Strings.toHexString(nativeVm.ethereumAddress),
      expiration: uint256(nativeVm.expiration) * 1000 // expiration in ms (cast from uint88)
    });
  }

  function _bytesToHexString(bytes memory input) public pure returns (string memory hexString) {
    return W3CResolverUtils.bytesToHexString(input);
  }
}
