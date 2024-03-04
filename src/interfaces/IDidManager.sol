// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { VerificationMethod } from "@src/VMStorage.sol";

/**
 * @dev Struct representing a command to update the controller of a DID.
 */
struct UpdateControllerCommand {
  bytes32 fromMethod0; // The first method component of the sender's DID.
  bytes32 fromMmethod1; // (optional) The second method component of the sender's DID.
  bytes32 fromMmethod2; // (optional) The third method component of the sender's DID.
  bytes32 fromId; // The unique identifier of the sender's DID.
  bytes32 fromVmId; // The unique identifier of the sender's VM.
  bytes32 toMethod0; // The first method component of the new to's DID to be modified.
  bytes32 toMethod1; // (optional) The second method component of the new to's DID to be modified.
  bytes32 toMethod2; // (optional) The third method component of the new to's DID to be modified.
  bytes32 toId; // The unique identifier of the new to's DID to be modified.
  bytes32 controllerMethod0; // The first method component of the new controller's DID.
  bytes32 controllerMethod1; // (optional) The second method component of the new controller's DID.
  bytes32 controllerMethod2; // (optional) The third method component of the new controller's DID.
  bytes32 controllerId; // The unique identifier of the new controller's DID.
  bytes32 controllerVmId; // (optional) The unique identifier of the new controller's VM.
  uint8 controllerPosition; // The position of the new controller's VM. if > CONTROLLER_MAX_LENGTH, it will overwrite the last controller.
}

/**
 * @title IDidManager
 * @dev Interface for managing Decentralized Identifiers (DIDs).
 */
interface IDidManager {
  /**
   * @dev Emitted when a new DID is created.
   * @param id The unique identifier of the DID.
   * @param idHash The hash of Method0, Method1, Method2, and ID.
   * @param creator The address of the account that created the DID.
   */
  event DidCreated(bytes32 indexed id, bytes32 indexed idHash, address indexed creator);

  /**
   * @dev Emitted when the controller of a DID is updated.
   * @param fromDidHash The unique identifier hash of the current DID.
   * @param toDidHash The unique identifier hash of the new DID.
   * @param controllerDidOrDidVmIdHash The unique identifier hash of the controller's DID or VM.
   * @param controllerPosition The position of the controller.
   */
  event ControllerUpdated(
    bytes32 indexed fromDidHash,
    bytes32 indexed toDidHash,
    bytes32 indexed controllerDidOrDidVmIdHash,
    uint8 controllerPosition
  );

  /**
   * @dev Creates a new DID.
   * @param method0 The first method component of the DID.
   * @param method1 (optional) The second method component of the DID.
   * @param method2 (optional) The third method component of the DID.
   * @param random A random value used to generate the DID.
   * @param vmId The ID of the Verification Method.
   */
  function createDid(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random,
    bytes32 vmId
  ) external;

  /**
   * @dev Returns the expiration timestamp for a given DID or VM ID.
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param id The ID.
   * @param vmId (optional) The VM ID.
   * @return exp The expiration timestamp.
   */
  function getExpiration(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external view returns (uint256 exp);

  /**
   * @dev Updates the controller of the DID manager.
   * @param command The command containing parameters.
   */
  function updateController(UpdateControllerCommand memory command) external;

  /**
   * @dev Creates a new Verification Method (VM) with the specified parameters.
   * @param method0 The first method of the VM.
   * @param method1 (optional) The second method of the VM.
   * @param method2 (optional) The third method of the VM.
   * @param id The ID of the VM.
   * @param vmId The ID of the verification method.
   * @param type_ An array of two bytes32 values representing the type of the VM.
   * @param publicKey An array of 16 bytes32 values representing the public key of the VM.
   * @param blockchainAccountId An array of 5 bytes32 values representing the blockchain account ID of the VM.
   * @param thisBCAddress The address of the blockchain where the VM is created.
   * @param relationships A bytes1 value representing the relationships of the VM.
   * @param expiration The expiration time of the VM.
   */
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

  /**
   * @dev Validates a  (VM) by checking its position hash and expiration.
   * @param positionHash The position hash of the VM.
   * @param expiration The expiration timestamp of the VM.
   */
  function validateVM(bytes32 positionHash, uint expiration) external;

  function getVM(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external view returns (VerificationMethod memory vm);
}
