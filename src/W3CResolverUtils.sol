// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { W3CService, W3CDidInput } from "./interfaces/IW3CResolver.sol";
import { Controller, CONTROLLERS_MAX_LENGTH, DEFAULT_DID_METHODS } from "./DidManagerBase.sol";
import { Service } from "@src/interfaces/IServiceStorage.sol";

error DidInputRequired();

/**
 * @title W3CResolverUtils
 * @author Miguel Gómez Carpena
 * @dev Shared utility library for W3C DID document resolution.
 * Contains common functions used by both W3CResolver and W3CResolverNative.
 */
library W3CResolverUtils {
  /**
   * @dev Validates DID input, reverting if id is zero. Sets default methods if empty.
   * @param didInput The DID input to validate.
   */
  function checkDidInput(W3CDidInput memory didInput) internal pure {
    if (didInput.id == bytes32(0)) {
      revert DidInputRequired();
    }
    if (didInput.methods == bytes32(0)) {
      didInput.methods = DEFAULT_DID_METHODS;
    }
  }

  /**
   * @dev Converts a Service struct to W3C format, parsing packed type_ and endpoint.
   * @param service The raw service from storage.
   * @return w3cService The W3C-formatted service.
   */
  function toW3cService(Service memory service) internal pure returns (W3CService memory w3cService) {
    string[] memory types = parsePackedStrings(service.type_);
    string[] memory serviceEndpoints = parsePackedStrings(service.serviceEndpoint);

    return W3CService({
      id: string(trimBytes(abi.encodePacked(service.id))), type_: types, serviceEndpoint: serviceEndpoints
    });
  }

  /**
   * @dev Converts controller array to W3C DID string array.
   * @param controllers The fixed-size controller array from storage.
   * @param methods The DID method bytes for formatting.
   * @return w3cControllers Array of W3C-formatted controller DID strings.
   */
  function toW3cController(Controller[CONTROLLERS_MAX_LENGTH] memory controllers, bytes32 methods)
    internal
    pure
    returns (string[] memory w3cControllers)
  {
    uint8 realLenght = 0;
    string[] memory temporalControllers = new string[](controllers.length);
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      if (controllers[i].id != bytes32(0)) {
        temporalControllers[realLenght] =
          formatDidString(W3CDidInput({ methods: methods, id: controllers[i].id, fragment: controllers[i].vmId }));
        realLenght++;
      }
    }
    w3cControllers = new string[](realLenght);
    for (uint8 i = 0; i < realLenght; i++) {
      w3cControllers[i] = temporalControllers[i];
    }
    return w3cControllers;
  }

  /**
   * @dev Formats a DID input into a W3C DID string: "did:method0:method1:method2:hexId#fragment"
   * @param didInput The DID input with methods, id, and optional fragment.
   * @return did The formatted DID string.
   */
  function formatDidString(W3CDidInput memory didInput) internal pure returns (string memory did) {
    bytes10 method0 = bytes10(didInput.methods);
    bytes10 method1 = bytes10(bytes32(uint256(didInput.methods) << 80));
    bytes10 method2 = bytes10(bytes32(uint256(didInput.methods) << 160));
    bytes memory finalEncode = abi.encodePacked("did:", method0, ":");
    if (method1 != bytes10(0)) {
      finalEncode = abi.encodePacked(finalEncode, method1, ":");
    }
    if (method2 != bytes10(0)) {
      finalEncode = abi.encodePacked(finalEncode, method2, ":");
    }
    finalEncode = abi.encodePacked(finalEncode, bytesToHexString(abi.encodePacked(didInput.id)));
    if (didInput.fragment != bytes32(0)) {
      finalEncode = abi.encodePacked(finalEncode, "#", didInput.fragment);
    }
    return string(trimBytes(finalEncode));
  }

  /**
   * @dev Parses packed bytes into string array using '\x00' as delimiter.
   * Example: "LinkedDomains\x00DIDCommMessaging" -> ["LinkedDomains", "DIDCommMessaging"]
   * @param packed The packed bytes with '\x00' delimited strings.
   * @return strings Array of parsed strings.
   */
  function parsePackedStrings(bytes memory packed) internal pure returns (string[] memory strings) {
    if (packed.length == 0) {
      return new string[](0);
    }

    // First pass: count delimiters to determine array size
    uint256 count = 1;
    for (uint256 i = 0; i < packed.length; i++) {
      if (packed[i] == 0x00) {
        count++;
      }
    }

    // Second pass: extract strings and track last non-empty index
    strings = new string[](count);
    uint256 stringIndex = 0;
    uint256 startPos = 0;
    uint256 lastNonEmpty = 0;

    for (uint256 i = 0; i <= packed.length; i++) {
      if (i == packed.length || packed[i] == 0x00) {
        uint256 strLen = i - startPos;
        if (strLen > 0) {
          bytes memory strBytes = new bytes(strLen);
          for (uint256 j = 0; j < strLen; j++) {
            strBytes[j] = packed[startPos + j];
          }
          strings[stringIndex] = string(strBytes);
          lastNonEmpty = stringIndex + 1;
        } else {
          strings[stringIndex] = "";
        }
        stringIndex++;
        startPos = i + 1;
      }
    }

    // Trim trailing empty strings if needed
    if (lastNonEmpty == 0) {
      return new string[](0);
    }
    if (lastNonEmpty < count) {
      string[] memory trimmed = new string[](lastNonEmpty);
      for (uint256 i = 0; i < lastNonEmpty; i++) {
        trimmed[i] = strings[i];
      }
      return trimmed;
    }

    return strings;
  }

  /**
   * @dev Removes zero bytes from a byte array, preserving non-zero content.
   * Returns empty bytes if the first byte is zero.
   * @param input The byte array to trim.
   * @return output The trimmed byte array.
   */
  function trimBytes(bytes memory input) internal pure returns (bytes memory output) {
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

  /**
   * @dev Converts a byte array to its lowercase hexadecimal string representation.
   * @param input The bytes to convert.
   * @return hexString The hex string without "0x" prefix.
   */
  function bytesToHexString(bytes memory input) internal pure returns (string memory hexString) {
    bytes memory converted = new bytes(input.length * 2);
    bytes memory _base = "0123456789abcdef";

    for (uint256 i = 0; i < input.length; i++) {
      converted[i * 2] = _base[uint8(input[i]) / _base.length];
      converted[i * 2 + 1] = _base[uint8(input[i]) % _base.length];
    }

    return string(converted);
  }
}
