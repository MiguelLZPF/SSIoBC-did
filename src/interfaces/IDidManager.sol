// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { VerificationMethod } from "@src/VMStorage.sol";
import { Service } from "@src/interfaces/IServiceStorage.sol";
import { Controller, DEFAULT_DID_METHODS, EXPIRATION, CONTROLLERS_MAX_LENGTH } from "@src/DidManagerBase.sol";

/**
 * @dev Command struct for creating a Verification Method via DidManager.
 * Uses optimized storage with dynamic bytes and packed expiration.
 */
struct CreateVmCommand {
  bytes32 methods; // The methods used to create the VM, concatenated each one limited to 10 bytes.
  bytes32 senderId; // The ID of the sender.
  bytes32 senderVmId; // The ID of the sender's VM.
  bytes32 targetId; // The ID of the target.
  bytes32 vmId; // The ID of the verification method.
  bytes32[2] type_; // The type of the VM.
  bytes publicKeyMultibase; // Pre-encoded multibase string (e.g., "z6MkhaXg...")
  bytes blockchainAccountId; // CAIP-10 format string (e.g., "eip155:1:0xabc...")
  address ethereumAddress; // The address of the blockchain where the VM is created.
  bytes1 relationships; // The relationships of the VM.
  uint88 expiration; // The expiration time of the VM (packed, max ~9.8 million years).
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
    bytes32 indexed senderDidHash, bytes32 indexed targetDidHash, uint8 controllerPosition, bytes32 vmId
  );

  /**
   * @dev Emitted when a DID is deactivated (permanently expired).
   * @param targetDidHash The hash of the deactivated DID.
   */
  event DidDeactivated(bytes32 indexed targetDidHash);

  /**
   * @dev Emitted when a deactivated DID is reactivated.
   * @param targetDidHash The hash of the reactivated DID.
   */
  event DidReactivated(bytes32 indexed targetDidHash);

  // * Errors
  // Shared errors (DidAlreadyExists, DidExpired, NotAuthenticatedAsSenderId,
  // NotAControllerforTargetId, DidNotDeactivated, MissingRequiredParameter)
  // are declared in DidManagerBase.sol

  /**
   * @dev Creates a new DID.
   * @param methods The methods used to create the DID.
   * @param random A random value used to generate the DID.
   * @param vmId The ID of the Verification Method.
   */
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external;

  /**
   * @dev Expires a Verification Method (VM).
   * @param methods The methods used to expire the VM.
   * @param senderId The ID of the sender.
   * @param senderVmId The ID of the sender's Verification Method.
   * @param targetId The ID of the target.
   * @param vmId The ID of the Verification Method to expire.
   */
  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId) external;

  /**
   * @dev Deactivates a DID permanently by setting its expiration to zero.
   * Once deactivated, a DID cannot be reactivated and will fail all operations.
   * This follows W3C DID Core specification for DID deactivation.
   * @param methods The methods used to identify the DID.
   * @param senderId The ID of the sender.
   * @param senderVmId The ID of the sender's Verification Method.
   * @param targetId The ID of the DID to deactivate.
   */
  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external;

  /**
   * @dev Reactivates a deactivated DID by setting its expiration to 4 years from now.
   * Only works on DIDs with expiration == 0 (deactivated, not just expired).
   * Requires the sender to have an active DID with valid VM and be a controller of the target.
   * @param methods The methods used to identify the DID.
   * @param senderId The ID of the sender.
   * @param senderVmId The ID of the sender's Verification Method.
   * @param targetId The ID of the DID to reactivate.
   */
  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external;

  /**
   * @dev Returns the expiration timestamp for a given DID or VM ID.
   * @param methods The methods used to expire the VM.
   * @param id The ID.
   * @param vmId (optional) The VM ID.
   * @return exp The expiration timestamp.
   */
  function getExpiration(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (uint256 exp);

  /**
   * @dev Authenticates a DID or VM.
   * @param methods The methods used for authentication.
   * @param id The ID.
   * @param vmId (optional) The VM ID.
   * @return true if the authentication is successful, false otherwise.
   */
  function authenticate(bytes32 methods, bytes32 id, bytes32 vmId, address sender) external view returns (bool);

  /**
   * @dev Checks if there is a VM relationship.
   * @param methods The methods used to check the VM relationship.
   * @param id The ID.
   * @param vmId The VM ID.
   * @param relationship The relationship identifier.
   * @return true if there is a VM relationship, false otherwise.
   */
  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    external
    view
    returns (bool);

  /**
   * @dev Updates the controller of the DID manager. This function can be used to:
   * - **Create**: Add a new controller at a specific position
   * - **Update**: Modify an existing controller at a given position
   * - **Remove**: Set controllerId to bytes32(0) to remove a controller at that position
   * @param methods The methods used to update the controller.
   * @param senderId The unique identifier of the sender's DID.
   * @param senderVmId The unique identifier of the sender's VM.
   * @param targetId The unique identifier of the new target's DID to be modified.
   * @param controllerId The unique identifier of the new controller's DID. Use bytes32(0) to remove.
   * @param controllerVmId (optional) The unique identifier of the new controller's VM.
   * @param controllerPosition The position of the controller (0-4). If greater than CONTROLLERS_MAX_LENGTH, it will
   * overwrite the last position.
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
  function getControllerList(bytes32 methods, bytes32 id)
    external
    view
    returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllerList);

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
  function validateVm(bytes32 positionHash, uint256 expiration) external;

  /**
   * @dev Returns the Verification Method (VM) for a given DID and VM ID.
   * @param methods The methods used to retrieve the VM list.
   * @param id The ID.
   * @param vmId The VM ID.
   * @param position The position of the Verification Method in the array.
   * @return vm The Verification Method.
   */
  function getVm(bytes32 methods, bytes32 id, bytes32 vmId, uint8 position)
    external
    view
    returns (VerificationMethod memory vm);

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
   * @param type_ Service types packed with '\x00' delimiter.
   * @param serviceEndpoint Service endpoints packed with '\x00' delimiter.
   */
  function updateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external;

  /**
   * @dev Returns the service for a given ID and (sercice position or service ID).
   * @param methods The methods used for the service.
   * @param id The ID.
   * @param serviceId The service ID.
   * @param position The position of the service.
   * @return service The service.
   */
  function getService(bytes32 methods, bytes32 id, bytes32 serviceId, uint8 position)
    external
    view
    returns (Service memory service);

  /**
   * @dev Returns the length of the service list for a given ID.
   * @param methods The methods used for the service.
   * @param id The ID.
   * @return length The length of the service list.
   */
  function getServiceListLength(bytes32 methods, bytes32 id) external view returns (uint8 length);
}
