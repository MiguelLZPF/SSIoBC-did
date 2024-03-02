// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

struct UpdateControllerCommand {
  bytes32 fromMethod0;
  bytes32 fromMmethod1;
  bytes32 fromMmethod2;
  bytes32 fromId;
  bytes32 fromVmId;
  bytes32 toMethod0;
  bytes32 toMethod1;
  bytes32 toMethod2;
  bytes32 toId;
  bytes32 controllerMethod0;
  bytes32 controllerMethod1;
  bytes32 controllerMethod2;
  bytes32 controllerId;
  bytes32 controllerVmId; // optional
  uint8 controllerPosition;
}

/**
 * @title IDidManager
 * @dev Interface for managing Decentralized Identifiers (DIDs).
 */
interface IDidManager {
  /**
   * @dev Emitted when a new DID is created.
   * @param idHash The unique identifier of the DID.
   * @param creator The address of the account that created the DID.
   */
  event DidCreated(bytes32 indexed idHash, address indexed creator);
  event VmCreated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bytes32 indexed vmIdHash,
    bytes32 positionHash
  );
  event VmValidated(bytes32 indexed id);
  event ControllerUpgdated(
    bytes32 indexed fromDidHash,
    bytes32 indexed toDidHash,
    bytes32 indexed controllerIdHash,
    bytes32 controllerVmIdHash,
    uint8 controllerPosition
  );

  /**
   * @dev Creates a new DID.
   * @param method0 The first method component of the DID.
   * @param method1 The second method component of the DID.
   * @param method2 The third method component of the DID.
   * @param random A random value used to generate the DID.
   */
  function createDid(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random,
    bytes32 vmId
  ) external;

  function createVM(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    bytes32[2] calldata type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId,
    address thisBCAddress,
    bytes1 relationships,
    uint expiration
  ) external;

  function validateVM(bytes32 positionHash, uint expiration) external;

  function updateController(UpdateControllerCommand memory command) external;
}
