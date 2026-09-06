// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

/// @title HashUtils
/// @author Miguel Gómez Carpena
/// @notice Shared hash utility library for DID storage indexing
library HashUtils {
  function calculatePositionHash(bytes32 namespace, uint8 position) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(namespace, position));
  }

  function calculateIdHash(bytes32 namespace, bytes32 id) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(namespace, id));
  }

  /**
   * @dev Builds a canonical `bytes32 methods` from three segment names.
   *
   * Solidity right-pads a short string literal cast to `bytes10` with `0x00`, but the canonical
   * padding byte is ";" (`METHOD_FILLER`), so `bytes32(bytes10("lzpf"))` is rejected by
   * `DidAggregate._validateMethods`. This helper does the conversion: everything from the first
   * `0x00` of a segment onward becomes ";", and the two unused tail bytes are ";;" too.
   *
   * Pass `bytes10(0)` for an unused segment. Segments must be left-packed, so an empty segment 1
   * requires an empty segment 2.
   *
   * @param method0 Segment 0, which becomes the DID `method-name`. Must be non-empty, `[a-z0-9]`.
   * @param method1 Segment 1, `[a-zA-Z0-9.-_]`, may be empty.
   * @param method2 Segment 2, same charset as segment 1, may be empty.
   * @return The canonical packed value, ready for `createDid`.
   */
  function packMethods(bytes10 method0, bytes10 method1, bytes10 method2) internal pure returns (bytes32) {
    return bytes32(
      (uint256(uint80(_padSegment(method0))) << 176) | (uint256(uint80(_padSegment(method1))) << 96)
        | (uint256(uint80(_padSegment(method2))) << 16) | 0x3B3B
    );
  }

  /// @dev Replaces every byte from the first `0x00` onward with ";".
  function _padSegment(bytes10 name) private pure returns (bytes10 out) {
    out = name;
    bool padding = false;
    for (uint256 i = 0; i < 10; i++) {
      if (!padding && name[i] == 0x00) {
        padding = true;
      }
      if (padding) {
        out |= bytes10(bytes1(0x3B)) >> (i * 8);
      }
    }
    return out;
  }
}
