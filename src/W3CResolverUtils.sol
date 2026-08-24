// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { W3CService, W3CDidInput } from "@types/W3CTypes.sol";
import {
  Controller,
  CONTROLLERS_MAX_LENGTH,
  DEFAULT_DID_METHODS,
  METHOD_FILLER,
  MethodPaddingMustBeSemicolon,
  MethodNameEmpty,
  MethodCharInvalid,
  MethodFillerNotTrailing,
  MethodSegmentsNotLeftPacked
} from "@types/DidTypes.sol";
import { Service } from "@types/ServiceTypes.sol";

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
  /**
   * @dev Splits `methods` into its three rendered segments, reverting if the value could not
   * produce a W3C-conformant or unambiguous DID string.
   *
   * This is the ONLY layer that enforces the method character rules. `createDid` deliberately
   * does not validate `methods`, because validating there costs every user gas (measured at
   * +13,183 on `createDid`) and buys nothing: every DID string in the system is built by
   * `formatDidString`, which calls this, so a value that cannot pass here has no string
   * representation at all. The consequence is that a malformed `methods` produces a DID that
   * exists on chain and works for `isAuthorized` but can never be resolved into a document.
   * `W3CResolverBase.checkMethods` is a free `pure` preflight for clients that want to catch
   * that before sending a transaction.
   *
   * Rules, each closing a concrete defect:
   * 1. Segment 0 non-empty, else the string starts `did::` with an empty `method-name`.
   * 2. Segment 0 is `[a-z0-9]` (`method-char = %x61-7A / DIGIT`).
   * 3. Segments 1 and 2 are `[a-zA-Z0-9.-_]` (`idchar`, minus pct-encoded), so a ":" cannot
   *    inject a segment and a "#" cannot inject a fragment that makes a parser read a
   *    different base DID.
   * 4. Filler is a trailing run only; interior filler would let "l;zpf" and "lzpf" render alike.
   * 5. Filler is exactly ";"; 0x00 padding would render alike for the same reason.
   * 6. Segments are left-packed, else ("lzpf","","test") and ("lzpf","test","") both render
   *    `did:lzpf:test:<id>`.
   * 7. The two unused tail bytes are ";;", which the rendered segments never expose.
   *
   * Together these make the `bytes32 methods` to DID-string mapping injective over every value
   * that has a string at all, so a DID string decodes back to exactly one `methods`.
   *
   * @param methods The packed methods value.
   * @return method0 Segment 0, the DID `method-name`.
   * @return method1 Segment 1, possibly empty.
   * @return method2 Segment 2, possibly empty.
   */
  function checkMethods(bytes32 methods)
    internal
    pure
    returns (bytes memory method0, bytes memory method1, bytes memory method2)
  {
    method0 = trimMethodSegment(bytes10(methods), true);
    method1 = trimMethodSegment(bytes10(bytes32(uint256(methods) << 80)), false);
    method2 = trimMethodSegment(bytes10(bytes32(uint256(methods) << 160)), false);
    if (method1.length == 0 && method2.length > 0) revert MethodSegmentsNotLeftPacked();
    if (uint16(uint256(methods)) != 0x3B3B) revert MethodPaddingMustBeSemicolon();
    return (method0, method1, method2);
  }

  function formatDidString(W3CDidInput memory didInput) internal pure returns (string memory did) {
    (bytes memory method0, bytes memory method1, bytes memory method2) = checkMethods(didInput.methods);
    bytes memory finalEncode = abi.encodePacked("did:", method0, ":");
    if (method1.length > 0) {
      finalEncode = abi.encodePacked(finalEncode, method1, ":");
    }
    if (method2.length > 0) {
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
   * @dev Strips the filler bytes a 10-byte method segment can carry, so only DID-legal
   * characters reach the DID string.
   *
   * Two filler bytes exist by design:
   * - `0x00`: Solidity right-pads a short string literal cast to `bytes10`.
   * - `0x3B` (";"): the project's explicit-empty marker (see `DEFAULT_DID_METHODS` in
   *   `DidTypes.sol`). It distinguishes "this segment is deliberately empty" from
   *   "this segment was never set", which zero-padding cannot express.
   *
   * Neither is a legal DID character. W3C DID Core v1.0 section 3.1 defines
   * `method-char = %x61-7A / DIGIT` and `idchar = ALPHA / DIGIT / "." / "-" / "_" /
   * pct-encoded`, so both fillers must be removed before the segment is emitted.
   * They remain untouched in storage; this is an output-only transformation.
   *
   * Trailing-only: filler after a name byte reverts, because stripping interior filler would make
   * two distinct `methods` values render the same string. Illegal characters revert too, so the
   * emitted DID is conformant even when `resolve` is handed a `methods` that was never stored.
   *
   * @param segment One 10-byte method segment.
   * @param isMethodName True for segment 0, which must be non-empty and `[a-z0-9]` only.
   * @return out The segment with its trailing filler removed (may be empty when not the name).
   */
  function trimMethodSegment(bytes10 segment, bool isMethodName) internal pure returns (bytes memory out) {
    uint256 length = 0;
    bool inFiller = false;
    for (uint256 i = 0; i < 10; i++) {
      bytes1 char = segment[i];
      if (char == METHOD_FILLER) {
        inFiller = true;
        continue;
      }
      // Only ";" is canonical filler. Accepting 0x00 too would let "lzpf" + 0x00*6 and
      // "lzpf" + ";"*6, two distinct values with distinct idHash, render the same DID string.
      if (char == 0x00) revert MethodPaddingMustBeSemicolon();
      // Filler is a trailing run only. Anything after it means the value was never canonical,
      // which `DidAggregate._validateMethods` prevents at write time but a caller can still
      // hand straight to `resolve`.
      if (inFiller) revert MethodFillerNotTrailing();
      bool legal = (char >= 0x61 && char <= 0x7A) || (char >= 0x30 && char <= 0x39); // a-z 0-9
      if (!isMethodName) {
        legal = legal || (char >= 0x41 && char <= 0x5A) || char == 0x2E || char == 0x2D || char == 0x5F;
      }
      if (!legal) revert MethodCharInvalid();
      length++;
    }
    if (isMethodName && length == 0) revert MethodNameEmpty();
    out = new bytes(length);
    for (uint256 i = 0; i < length; i++) {
      out[i] = segment[i];
    }
    return out;
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
