// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

library HashUtils {
  function calculatePositionHash(bytes32 namespace, uint8 position) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(namespace, position));
  }

  function calculateIdHash(bytes32 namespace, bytes32 id) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(namespace, id));
  }
}
