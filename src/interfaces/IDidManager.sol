// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { VerificationMethod } from "@src/VMStorage.sol";

/**
 * @dev Struct representing a controller of a DID.
 */
struct Controller {
  bytes32 id; // The unique identifier of the controller's DID.
  bytes32 vmId; // (optional) The unique identifier of the controller's VM.
}

bytes32 constant METHOD0 = bytes32("lzpf");
bytes32 constant METHOD1 = bytes32("main");
bytes32 constant METHOD2 = bytes32(0); // not used by default
uint constant EXPIRATION = 126144000; // 4 years in seconds (4 * 365 * 24 * 60 * 60)
uint8 constant CONTROLLERS_MAX_LENGTH = 5;

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
   * @param controllerPosition The position of the controller.
   * @param method0 The first method component of the controller's DID.
   * @param method1 (optional) The second method component of the controller's DID.
   * @param method2 (optional) The third method component of the controller's DID.
   * @param id The unique identifier of the controller's DID.
   * @param vmId (optional) The unique identifier of the controller's VM.
   */
  event ControllerUpdated(
    bytes32 indexed fromDidHash,
    bytes32 indexed toDidHash,
    uint8 controllerPosition,
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
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
   * @dev Authenticates a DID or VM.
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param id The ID.
   * @param vmId (optional) The VM ID.
   * @return true if the authentication is successful, false otherwise.
   */
  function authenticate(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    address sender
  ) external view returns (bool);

  /**
   * @dev Checks if there is a VM relationship.
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param id The ID.
   * @param vmId The VM ID.
   * @param relationship The relationship identifier.
   * @return true if there is a VM relationship, false otherwise.
   */
  function isVmRelationship(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    bytes1 relationship,
    address sender
  ) external view returns (bool);

  /**
   * @dev Updates the controller of the DID manager.
   * @param method0 The first method component of the DIDs.
   * @param method1 (optional) The second method component of the DIDs.
   * @param method2 (optional) The third method component of the DIDs.
   * @param fromId The unique identifier of the sender's DID.
   * @param fromVmId The unique identifier of the sender's VM.
   * @param toId The unique identifier of the new to's DID to be modified.
   * @param controllerId The unique identifier of the new controller's DID.
   * @param controllerVmId (optional) The unique identifier of the new controller's VM.
   * @param controllerPosition The position of the new controller's VM. If greater than CONTROLLER_MAX_LENGTH, it will overwrite the last controller.
   */
  function updateController(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 fromId,
    bytes32 fromVmId,
    bytes32 toId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external;

  /**
   * @dev Returns the list of controllers for a given DID.
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param id The ID.
   * @return controllerList The list of controllers.
   */
  function getControllerList(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) external view returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllerList);

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
   * @dev Validates a Verification Method (VM) by checking its position hash and expiration.
   * @param positionHash The position hash of the VM.
   * @param expiration The expiration timestamp of the VM.
   */
  function validateVM(bytes32 positionHash, uint expiration) external;

  /**
   * @dev Returns the Verification Method (VM) for a given DID and VM ID.
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param id The ID.
   * @param vmId The VM ID.
   * @return vm The Verification Method.
   */
  function getVM(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external view returns (VerificationMethod memory vm);

  /**
   * @dev Returns the length of the Verification Method (VM) list for a given DID.
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param id The ID.
   * @return length The length of the VM list.
   */
  function getVmListLength(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) external view returns (uint8);
}
