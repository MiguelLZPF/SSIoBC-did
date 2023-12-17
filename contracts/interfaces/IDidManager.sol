// SPDX-License-Identifier: UNLICENSED

/**
 * @title IDidManager
 * @dev Interface for managing Decentralized Identifiers (DIDs).
 */
pragma solidity >=0.8.0 <0.9.0;

interface IDidManager {
  /**
   * @dev Emitted when a new DID is created.
   * @param id The unique identifier of the DID.
   * @param creator The address of the account that created the DID.
   */
  event DidCreated(bytes32 indexed id, address indexed creator);

  /**
   * @dev Creates a new DID.
   * @param method0 The first method component of the DID.
   * @param method1 The second method component of the DID.
   * @param method2 The third method component of the DID.
   * @param random A random value used to generate the DID.
   */
  function createDid(
    bytes32 random,
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 vmId
  ) external;
}
