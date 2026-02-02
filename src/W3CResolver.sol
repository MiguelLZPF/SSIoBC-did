// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {
  IW3CResolver,
  W3CDidDocument,
  W3CVerificationMethod,
  W3CService,
  W3CDidInput
} from "./interfaces/IW3CResolver.sol";
import { IDidManager, Controller, CONTROLLERS_MAX_LENGTH, DEFAULT_DID_METHODS } from "./interfaces/IDidManager.sol";
import { VerificationMethod } from "@src/VMStorage.sol";
import { Service } from "@src/interfaces/IServiceStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// ! This Contract is NOT necessary, only adds ONchain DID resolution
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
      services[i] = _toW3cService(
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
      id: _formatDidString(didInput),
      controller: _toW3cController(_didManager.getControllerList(didInput.methods, didInput.id), didInput.methods),
      verificationMethod: vms,
      authentication: methods[0],
      assertionMethod: methods[1],
      keyAgreement: methods[2],
      capabilityDelegation: methods[3],
      capabilityInvocation: methods[4],
      service: services,
      expiration: _didManager.getExpiration(didInput.methods, didInput.id, bytes32(0)) * 1000
    });
  }

  function resolveVm(W3CDidInput memory didInput, bytes32 vmId) public view returns (W3CVerificationMethod memory vm) {
    // * Check parameters
    // Required
    _checkDidInput(didInput);
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
    _checkDidInput(didInput);
    // * Implementation
    return _toW3cService(_didManager.getService(didInput.methods, didInput.id, serviceId, 0));
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
        string memory methodString =
          _formatDidString(W3CDidInput({ methods: didInput.methods, id: didInput.id, fragment: vm.id }));
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
      id: string(_trimBytes(abi.encodePacked(vm.id))),
      type_: string(_trimBytes(abi.encodePacked(vm.type_))),
      controller: _formatDidString(didInput),
      publicKeyMultibase: string(vm.publicKeyMultibase),
      blockchainAccountId: string(vm.blockchainAccountId), // CAIP-10 string, stored as-is
      ethereumAddress: Strings.toHexString(vm.ethereumAddress),
      expiration: uint256(vm.expiration) * 1000 // expiration in ms (cast from uint88)
    });
  }

  function _toW3cService(Service memory service) internal pure returns (W3CService memory w3cService) {
    // Parse packed bytes into string arrays using '\x00' delimiter
    string[] memory types = _parsePackedStrings(service.type_);
    string[] memory serviceEndpoints = _parsePackedStrings(service.serviceEndpoint);

    return W3CService({
      id: string(_trimBytes(abi.encodePacked(service.id))),
      type_: types,
      serviceEndpoint: serviceEndpoints
    });
  }

  /**
   * @dev Parses packed bytes into string array using '\x00' as delimiter.
   * Example: "LinkedDomains\x00DIDCommMessaging" -> ["LinkedDomains", "DIDCommMessaging"]
   * @param packed The packed bytes with '\x00' delimited strings.
   * @return strings Array of parsed strings.
   */
  function _parsePackedStrings(bytes memory packed) internal pure returns (string[] memory strings) {
    if (packed.length == 0) {
      return new string[](0);
    }

    // First pass: count delimiters to determine array size
    uint256 count = 1; // At least one string if not empty
    for (uint256 i = 0; i < packed.length; i++) {
      if (packed[i] == 0x00) {
        count++;
      }
    }

    // Second pass: extract strings
    strings = new string[](count);
    uint256 stringIndex = 0;
    uint256 startPos = 0;

    for (uint256 i = 0; i <= packed.length; i++) {
      // Check for delimiter or end of array
      if (i == packed.length || packed[i] == 0x00) {
        uint256 strLen = i - startPos;
        if (strLen > 0) {
          bytes memory strBytes = new bytes(strLen);
          for (uint256 j = 0; j < strLen; j++) {
            strBytes[j] = packed[startPos + j];
          }
          strings[stringIndex] = string(strBytes);
        } else {
          strings[stringIndex] = "";
        }
        stringIndex++;
        startPos = i + 1;
      }
    }

    // Trim array if we have trailing empty strings from consecutive delimiters
    // Count actual non-empty strings or necessary empty strings
    uint256 actualCount = 0;
    for (uint256 i = 0; i < strings.length; i++) {
      if (bytes(strings[i]).length > 0) {
        actualCount = i + 1; // Keep all strings up to and including the last non-empty one
      }
    }

    // If all strings are empty (edge case), return empty array
    if (actualCount == 0 && strings.length > 0 && bytes(strings[0]).length == 0) {
      return new string[](0);
    }

    // Create properly sized array
    if (actualCount < strings.length) {
      string[] memory trimmed = new string[](actualCount);
      for (uint256 i = 0; i < actualCount; i++) {
        trimmed[i] = strings[i];
      }
      return trimmed;
    }

    return strings;
  }

  function _toW3cController(Controller[CONTROLLERS_MAX_LENGTH] memory controllers, bytes32 methods)
    internal
    pure
    returns (string[] memory w3cControllers)
  {
    uint8 realLenght = 0;
    string[] memory temporalControllers = new string[](controllers.length);
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      if (controllers[i].id != bytes32(0)) {
        temporalControllers[realLenght] =
          _formatDidString(W3CDidInput({ methods: methods, id: controllers[i].id, fragment: controllers[i].vmId }));
        realLenght++;
      }
    }
    w3cControllers = new string[](realLenght);
    for (uint8 i = 0; i < realLenght; i++) {
      w3cControllers[i] = temporalControllers[i];
    }
    return w3cControllers;
  }

  function _checkDidInput(W3CDidInput memory didInput) internal pure {
    // * Check parameters
    // Required
    require(didInput.id != bytes32(0), "DID cant be 0");
    // Optional
    // Default values if not provided
    if (didInput.methods == bytes32(0)) {
      didInput.methods = DEFAULT_DID_METHODS;
    }
  }

  function _formatDidString(W3CDidInput memory didInput) internal pure returns (string memory did) {
    // Get the method identifiers from the provided bytes32 value
    bytes10 method0 = bytes10(didInput.methods);
    bytes10 method1 = bytes10(bytes32(uint256(didInput.methods) << 80)); // Shift to get the second 10 bytes
    bytes10 method2 = bytes10(bytes32(uint256(didInput.methods) << 160)); // Shift to get the third 10 bytes
      // The final bytes buffer to be converted to string
    bytes memory finalEncode = abi.encodePacked("did:", method0, ":");
    if (method1 != bytes10(0)) {
      finalEncode = abi.encodePacked(finalEncode, method1, ":");
    }
    if (method2 != bytes10(0)) {
      finalEncode = abi.encodePacked(finalEncode, method2, ":");
    }
    finalEncode = abi.encodePacked(finalEncode, _bytesToHexString(abi.encodePacked(didInput.id)));
    if (didInput.fragment != bytes32(0)) {
      finalEncode = abi.encodePacked(finalEncode, "#", didInput.fragment);
    }
    return string(_trimBytes(finalEncode));
  }

  function _trimBytes(bytes memory input) internal pure returns (bytes memory output) {
    if (input[0] == 0x00) {
      return new bytes(0);
    }
    bytes memory withoutZeros = new bytes(input.length);
    uint256 length = 0;
    for (uint256 i = 0; i < input.length; i++) {
      if (input[i] != 0x00) {
        withoutZeros[length] = input[i];
        length++;
      }
    }
    output = new bytes(length);
    for (uint256 i = 0; i < length; i++) {
      output[i] = withoutZeros[i];
    }
    return output;
  }

  function _bytesToHexString(bytes memory input) public pure returns (string memory hexString) {
    // Fixed buffer size for hexadecimal convertion
    bytes memory converted = new bytes(input.length * 2);
    bytes memory _base = "0123456789abcdef";

    for (uint256 i = 0; i < input.length; i++) {
      converted[i * 2] = _base[uint8(input[i]) / _base.length];
      converted[i * 2 + 1] = _base[uint8(input[i]) % _base.length];
    }

    return string(converted);
  }
}
