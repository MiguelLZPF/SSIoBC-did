// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { VerificationMethod } from "@src/VMStorageNative.sol";
import { Service } from "@src/interfaces/IServiceStorage.sol";
import { Controller, CONTROLLERS_MAX_LENGTH } from "@src/DidManagerBase.sol";

/**
 * @dev Command struct for creating a native Verification Method via DidManagerNative.
 * Simplified: only 8 fields (vs 11 in the full variant).
 * No type_, blockchainAccountId, or expiration.
 * publicKeyMultibase is REQUIRED when keyAgreement (0x04) is set, and FORBIDDEN otherwise.
 */
struct CreateVmCommand {
  bytes32 methods; // The DID methods
  bytes32 senderId; // The ID of the sender
  bytes32 senderVmId; // The ID of the sender's VM
  bytes32 targetId; // The ID of the target DID
  bytes32 vmId; // The ID of the verification method
  address ethereumAddress; // MANDATORY - the Ethereum address
  bytes1 relationships; // The relationships of the VM
  bytes publicKeyMultibase; // Required IFF keyAgreement (0x04) is set; pre-encoded multibase (must start with 'z')
}

/**
 * @title IDidManagerNative
 * @dev Interface for managing Ethereum-native DIDs with 1-slot VM storage.
 * Produces identical W3C output via resolution-time derivation.
 */
interface IDidManagerNative {
  event DidCreated(bytes32 indexed id, bytes32 indexed idHash);
  event ControllerUpdated(
    bytes32 indexed senderDidHash, bytes32 indexed targetDidHash, uint8 controllerPosition, bytes32 vmId
  );
  event DidDeactivated(bytes32 indexed targetDidHash);
  event DidReactivated(bytes32 indexed targetDidHash);

  // Errors are declared as file-level in DidManagerBase.sol

  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external;

  function createVm(CreateVmCommand memory command) external;

  function validateVm(bytes32 positionHash, uint256 expiration) external;

  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId) external;

  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external;

  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external;

  function getExpiration(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (uint256 exp);

  function authenticate(bytes32 methods, bytes32 id, bytes32 vmId, address sender) external view returns (bool);

  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    external
    view
    returns (bool);

  function updateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external;

  function getControllerList(bytes32 methods, bytes32 id)
    external
    view
    returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllerList);

  function getVm(bytes32 methods, bytes32 id, bytes32 vmId, uint8 position)
    external
    view
    returns (VerificationMethod memory vm);

  function getVmListLength(bytes32 methods, bytes32 id) external view returns (uint8);

  /**
   * @dev Returns the publicKeyMultibase for a native VM. Empty for non-keyAgreement VMs.
   */
  function getVmPublicKeyMultibase(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (bytes memory);

  /**
   * @dev Returns the VM ID at a given position. Used by W3CResolverNative for document construction.
   */
  function getVmIdAtPosition(bytes32 methods, bytes32 id, uint8 position) external view returns (bytes32);

  function updateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external;

  function getService(bytes32 methods, bytes32 id, bytes32 serviceId, uint8 position)
    external
    view
    returns (Service memory service);

  function getServiceListLength(bytes32 methods, bytes32 id) external view returns (uint8 length);
}
