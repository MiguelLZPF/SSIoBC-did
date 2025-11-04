// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Helper {
  /**
   * @dev Helper function to trim the surrounding brackets from a JSON array string.
   * @param json The JSON array string to be trimmed.
   * @return The trimmed JSON string without the surrounding brackets.
   */
  function _trimBrackets(string memory json) internal pure returns (string memory) {
    bytes memory jsonBytes = bytes(json);
    if (jsonBytes.length < 2) {
      return json; // Return as-is if too short to trim
    }

    // Create a new bytes array that is 2 characters shorter (removing the first and last characters)
    bytes memory trimmedBytes = new bytes(jsonBytes.length - 2);

    // Copy the characters, skipping the first and last ones
    for (uint256 i = 1; i < jsonBytes.length - 1; i++) {
      trimmedBytes[i - 1] = jsonBytes[i];
    }

    return string(trimmedBytes);
  }

  /**
   * @dev Trims leading and trailing whitespace from a given bytes array.
   * @param input The bytes array to be trimmed.
   * @return output The trimmed bytes array.
   */
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

  /**
   * @dev Converts a bytes array to its hexadecimal string representation.
   * @param input The bytes array to be converted.
   * @return hexString The hexadecimal string representation of the input bytes array.
   */
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
