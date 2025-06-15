// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { VerificationMethod } from "@src/VMStorage.sol";
import { Service, SERVICE_MAX_LENGTH_LIST, SERVICE_MAX_LENGTH } from "@src/ServiceStorage.sol";

/**
 * @dev Struct representing a controller of a DID.
 */
struct Controller {
  bytes32 id; // The unique identifier of the controller's DID.
  bytes32 vmId; // (optional) The unique identifier of the controller's VM.
}

struct CreateVmCommand {
  bytes32 methods; // The methods used to create the VM, concatenated each one limited to 10 bytes.
  bytes32 senderId; // The ID of the sender.
  bytes32 senderVmId; // The ID of the sender's VM.
  bytes32 targetId; // The ID of the target.
  bytes32 vmId; // The ID of the verification method.
  bytes32[2] type_; // The type of the VM.
  bytes32[16] publicKeyMultibase; // The public key of the VM.
  bytes32[5] blockchainAccountId; // The blockchain account ID of the VM.
  address ethereumAddress; // The address of the blockchain where the VM is created.
  bytes1 relationships; // The relationships of the VM.
  uint expiration; // The expiration time of the VM.
}

bytes32 constant DEFAULT_DID_METHODS = bytes32("lzpf;;;;;;main;;;;;;;;;;;;;;;;;;"); // ";" is the null or escape character
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
   */
  event DidCreated(bytes32 indexed id, bytes32 indexed idHash);

  /**
   * @dev Emitted when the controller of a DID is updated.
   * @param senderDidHash The hash of the sender's DID.
   * @param targetDidHash The hash of the target DID.
   * @param controllerPosition The position of the controller in the controller list.
   * @param vmId The ID of the VM.
   */
  event ControllerUpdated(
    bytes32 indexed senderDidHash,
    bytes32 indexed targetDidHash,
    uint8 controllerPosition,
    bytes32 vmId
  );

  // Declared in IVMStorage.sol
  // error MissingRequiredParameter();

  error DidAlreadyExists();

  error DidExpired();

  error NotAuthenticatedAsSenderId();

  error NotAControllerforTargetId();

  /**
   * @dev Creates a new DID.
   * @param methods The methods used to create the DID.
   * @param random A random value used to generate the DID.
   * @param vmId The ID of the Verification Method.
   */
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external;

  /**
   * @dev Updates the expiration date for a given ID hash.
   * @param idHash The hash of the ID to update the expiration date for.
   * @param forceExpire Boolean flag indicating whether to force expiration or not.
   *                   If set to true, the expiration date will be set to 0, effectively expiring the ID.
   *                   If set to false, the expiration date will be set to the current block timestamp plus the EXPIRATION value.
   */
  function updateExpiration(bytes32 idHash, bool forceExpire) external;

  /**
   * @dev Expires a Verification Method (VM).
   * @param methods The methods used to expire the VM.
   * @param senderId The ID of the sender.
   * @param senderVmId The ID of the sender's Verification Method.
   * @param targetId The ID of the target.
   * @param vmId The ID of the Verification Method to expire.
   */
  function expireVm(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 vmId
  ) external;

  /**
   * @dev Returns the expiration timestamp for a given DID or VM ID.
   * @param methods The methods used to expire the VM.
   * @param id The ID.
   * @param vmId (optional) The VM ID.
   * @return exp The expiration timestamp.
   */
  function getExpiration(
    bytes32 methods,
    bytes32 id,
    bytes32 vmId
  ) external view returns (uint256 exp);

  /**
   * @dev Authenticates a DID or VM.
   * @param methods The methods used for authentication.
   * @param id The ID.
   * @param vmId (optional) The VM ID.
   * @return true if the authentication is successful, false otherwise.
   */
  function authenticate(
    bytes32 methods,
    bytes32 id,
    bytes32 vmId,
    address sender
  ) external view returns (bool);

  /**
   * @dev Checks if there is a VM relationship.
   * @param methods The methods used to check the VM relationship.
   * @param id The ID.
   * @param vmId The VM ID.
   * @param relationship The relationship identifier.
   * @return true if there is a VM relationship, false otherwise.
   */
  function isVmRelationship(
    bytes32 methods,
    bytes32 id,
    bytes32 vmId,
    bytes1 relationship,
    address sender
  ) external view returns (bool);

  /**
   * @dev Updates the controller of the DID manager.
   * @param methods The methods used to update the controller.
   * @param senderId The unique identifier of the sender's DID.
   * @param senderVmId The unique identifier of the sender's VM.
   * @param targetId The unique identifier of the new target's DID to be modified.
   * @param controllerId The unique identifier of the new controller's DID.
   * @param controllerVmId (optional) The unique identifier of the new controller's VM.
   * @param controllerPosition The position of the new controller's VM. If greater than CONTROLLER_MAX_LENGTH, it will overwrite the last controller.
   */
  function updateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external;

  /**
   * @dev Returns the list of controllers for a given DID.
   * @param methods The methods used to retrieve the controller list.
   * @param id The ID.
   * @return controllerList The list of controllers.
   */
  function getControllerList(
    bytes32 methods,
    bytes32 id
  ) external view returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllerList);

  /**
   * @dev Creates a new Verification Method (VM) based on the provided command.
   * @param command The command containing the necessary information to create the VM.
   */
  function createVm(CreateVmCommand memory command) external;

  /**
   * @dev Validates a Verification Method (VM) by checking its position hash and expiration.
   * @param positionHash The position hash of the VM.
   * @param expiration The expiration timestamp of the VM.
   */
  function validateVm(bytes32 positionHash, uint expiration) external;

  /**
   * @dev Returns the Verification Method (VM) for a given DID and VM ID.
   * @param methods The methods used to retrieve the VM list.
   * @param id The ID.
   * @param vmId The VM ID.
   * @param position The position of the Verification Method in the array.
   * @return vm The Verification Method.
   */
  function getVm(
    bytes32 methods,
    bytes32 id,
    bytes32 vmId,
    uint8 position
  ) external view returns (VerificationMethod memory vm);

  /**
   * @dev Returns the length of the Verification Method (VM) list for a given DID.
   * @param methods The methods used to retrieve the VM list.
   * @param id The ID.
   * @return length The length of the VM list.
   */
  function getVmListLength(bytes32 methods, bytes32 id) external view returns (uint8);

  /**
   * @dev Updates, creates or removes a service for a given ID.
   * @param methods The methods used for the service.
   * @param senderId The unique identifier of the sender's DID.
   * @param senderVmId The unique identifier of the sender's VM.
   * @param targetId The unique identifier of the new target's DID to be modified.
   * @param serviceId The service ID.
   * @param type_ An array of service types.
   * @param serviceEndpoint An array of service endpoints.
   */
  function updateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory type_,
    bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory serviceEndpoint
  ) external;

  /**
   * @dev Returns the service for a given ID and (sercice position or service ID).
   * @param methods The methods used for the service.
   * @param id The ID.
   * @param serviceId The service ID.
   * @param position The position of the service.
   * @return service The service.
   */
  function getService(
    bytes32 methods,
    bytes32 id,
    bytes32 serviceId,
    uint8 position
  ) external view returns (Service memory service);

  /**
   * @dev Returns the length of the service list for a given ID.
   * @param methods The methods used for the service.
   * @param id The ID.
   * @return length The length of the service list.
   */
  function getServiceListLength(bytes32 methods, bytes32 id) external view returns (uint8 length);
}
