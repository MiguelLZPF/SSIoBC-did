// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IDidManager} from "./interfaces/IDidManager.sol";

contract DidManager is IDidManager {
  // DIDs are stored in a mapping of mappings of mappings that represents something like --> did:method0:method1:method2:id
  bytes32 private constant METHOD0 =
    bytes32(0x6c7a706600000000000000000000000000000000000000000000000000000000); // "lzpf"
  bytes32 private constant METHOD1 =
    bytes32(0x6d61696e00000000000000000000000000000000000000000000000000000000); // "main"
  bytes32 private constant METHOD2 = bytes32(0); // not used by default
  uint32 private constant EXPIRATION = 126144000; // 4 years in seconds (4 * 365 * 24 * 60 * 60)
  //      method0    -->     method1    -->     method2 -->   id
  // mapping(bytes32 => mapping(bytes32 => mapping(bytes32 => bytes32))) private dids;
  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint256) private expirationDate;

  constructor() {}

  /**
   * @dev Creates a new Decentralized Identifier (DID) using the specified method identifiers and a random value.
   * The method identifiers can be optionally provided, and if any of them is not provided (i.e., set to 0),
   * the default method identifier will be used instead.
   *
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param random A random value used to generate the DID. You can use uuidv4() to generate a random value, for example.
   *
   * Requirements:
   * - The random value must not be zero.
   * - The generated DID must not already exist.
   *
   * Emits a `DidCreated` event with the generated DID and the address of the caller.
   */
  function createDid(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random
  ) public override {
    require(random != bytes32(0), "Random cannot be 0");
    if (method0 == bytes32(0)) {
      method0 = METHOD0;
    }
    if (method1 == bytes32(0)) {
      method1 = METHOD1;
    }
    if (method2 == bytes32(0)) {
      method2 = METHOD2;
    }
    bytes32 id = keccak256(
      abi.encodePacked(method0, method1, method2, random, msg.sender, block.timestamp)
    );
    bytes32 idHash = keccak256(abi.encodePacked(method0, method1, method2, id));
    require(_isExpired(idHash), "DID already exists");
    _updateExpiration(idHash);
    emit DidCreated(id, msg.sender);
  }

  /**
   * @dev Updates the expiration date for a given ID hash.
   * @param idHash The hash of the ID to update the expiration date for.
   */
  function _updateExpiration(bytes32 idHash) internal {
    expirationDate[idHash] = block.timestamp + EXPIRATION;
  }

  /**
   * @dev Checks if a given ID hash is expired.
   * @param idHash The hash of the ID to check.
   * @return expired True if the ID is expired, false otherwise.
   */
  function _isExpired(bytes32 idHash) internal view returns (bool expired) {
    // Check if now is greater than expiration date or 0
    if (block.timestamp > expirationDate[idHash] || expirationDate[idHash] == 0) {
      return true;
    } else {
      return false;
    }
  }
}
