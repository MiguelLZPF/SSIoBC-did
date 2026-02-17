// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import {
  IW3CResolver,
  W3CDidDocument,
  W3CVerificationMethod,
  W3CService,
  W3CDidInput
} from "./interfaces/IW3CResolver.sol";
import { IDidManager } from "./interfaces/IDidManager.sol";
import { VerificationMethod } from "@src/VMStorage.sol";
import { W3CResolverUtils } from "@src/W3CResolverUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title W3CResolver
/// @author Miguel Gómez Carpena
/// @notice W3C DID document resolver (full variant)
contract W3CResolver is IW3CResolver {
  string[] private DEFAULT_CONTEXT = ["https://www.w3.org/ns/did/v1"];
  // * The DID Manager contract
  IDidManager internal _didManager;

  constructor(IDidManager didManager) {
    _didManager = didManager;
  }

  function resolve(W3CDidInput memory didInput, bool includeExpired)
    external
    view
    returns (W3CDidDocument memory didDocument)
  {
    // * Get Verification Methods
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
    // * Check parameters
    // Required
    W3CResolverUtils.checkDidInput(didInput);
    // * Implementation
    return _toW3cVerificationMethod(_didManager.getVm(didInput.methods, didInput.id, vmId, 0), didInput);
  }

  function resolveService(W3CDidInput memory didInput, bytes32 serviceId)
    public
    view
    returns (W3CService memory service)
  {
    // * Check parameters
    // Required
    W3CResolverUtils.checkDidInput(didInput);
    // * Implementation
    return W3CResolverUtils.toW3cService(_didManager.getService(didInput.methods, didInput.id, serviceId, 0));
  }

  // * Internal functions

  function _getAllVerificationMethods(W3CDidInput memory didInput, bool includeExpired)
    internal
    view
    returns (W3CVerificationMethod[] memory vms, string[][] memory methods)
  {
    // * (0) Temporal variables creation
    // Create temporal arrays for each method (5 methods)
    string[][] memory methodsTemp = new string[][](5);
    // Get the max length of the VM list (including expired ones)
    uint8 maxLength = _didManager.getVmListLength(didInput.methods, didInput.id);
    // Set the max length of the arrays to the max length of the VM list
    for (uint8 i = 0; i < 5; i++) {
      methodsTemp[i] = new string[](maxLength);
    }
    // Create an array to store temporary VMs
    W3CVerificationMethod[] memory vmsTemp = new W3CVerificationMethod[](maxLength);
    // Create an array to store the real length of each method (positions 1-5) and the vms (position 0)
    uint8[] memory realLength = new uint8[](6);
    // * (1) Iterate over the VM list
    // Iterate over the VM list (remember that the first position is 1, not 0)
    for (uint8 i = 1; i <= maxLength; i++) {
      VerificationMethod memory vm = _didManager.getVm(didInput.methods, didInput.id, bytes32(0), i);
      // Check if expired should be included or if the VM is not expired
      if (includeExpired || (vm.expiration != 0 && vm.expiration > block.timestamp)) {
        // Add the VM to the temporary array in W3C format
        vmsTemp[realLength[0]] = _toW3cVerificationMethod(vm, didInput);
        realLength[0]++;
        // Add the VM to the corresponding method array
        string memory methodString = W3CResolverUtils.formatDidString(
          W3CDidInput({ methods: didInput.methods, id: didInput.id, fragment: vm.id })
        );
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
    // * (2) Create the final arrays
    // Create the final array for the VMs
    vms = new W3CVerificationMethod[](realLength[0]);
    for (uint8 i = 0; i < realLength[0]; i++) {
      vms[i] = vmsTemp[i];
    }
    // Create the final arrays for the methods
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

  function _toW3cVerificationMethod(VerificationMethod memory vm, W3CDidInput memory didInput)
    internal
    pure
    returns (W3CVerificationMethod memory w3cVm)
  {
    // publicKeyMultibase is pre-encoded, just convert bytes to string
    return W3CVerificationMethod({
      id: string(W3CResolverUtils.trimBytes(abi.encodePacked(vm.id))),
      type_: string(W3CResolverUtils.trimBytes(abi.encodePacked(vm.type_))),
      controller: W3CResolverUtils.formatDidString(didInput),
      publicKeyMultibase: string(vm.publicKeyMultibase),
      blockchainAccountId: string(vm.blockchainAccountId), // CAIP-10 string, stored as-is
      ethereumAddress: Strings.toHexString(vm.ethereumAddress),
      expiration: uint256(vm.expiration) * 1000 // expiration in ms (cast from uint88)
    });
  }

  function _bytesToHexString(bytes memory input) public pure returns (string memory hexString) {
    return W3CResolverUtils.bytesToHexString(input);
  }
}
