// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {
  IDidManager,
  Controller,
  CreateVmCommand as DidCreateVmCommand,
  DEFAULT_DID_METHODS,
  EXPIRATION,
  CONTROLLERS_MAX_LENGTH
} from "src/interfaces/IDidManager.sol";
import { VMStorage, VerificationMethod, CreateVmCommand } from "src/VMStorage.sol";
import { ServiceStorage } from "src/ServiceStorage.sol";
import { Service } from "src/interfaces/IServiceStorage.sol";
import { HashUtils } from "src/HashUtils.sol";

// import {ServiceStorage} from "./ServiceStorage.sol";

contract DidManager is IDidManager, VMStorage, ServiceStorage {
  // DIDs are stored in a mapping that maps a bytes32 key (representing the hash of the DID) to its expiration date.
  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint256) private _expirationDate;
  // DID controllers are stored in a mapping that maps a bytes32 key (representing the hash of the DID or the hash of a
  // specific VM) to an array of 5 bytes32 values (representing the actual controllers).
  // hash(method0:method1:method2:id) --> controller[0..4]
  mapping(bytes32 => Controller[CONTROLLERS_MAX_LENGTH]) private _controllers;

  /**
   * @dev Creates a new Decentralized Identifier (DID) using the specified method identifiers and a random value.
   * The method identifiers can be optionally provided, and if any of them is not provided (i.e., set to 0),
   * the default method identifier will be used instead.
   *
   * @param methods A bytes32 value containing three method identifiers concatenated together.
   * @param random A random value used to generate the DID. You can use uuidv4() to generate a random value, for
   * example.
   *
   * Requirements:
   * - The random value must not be zero.
   * - The generated DID must not already exist.
   *
   * Emits a `DidCreated` event with the generated DID and the address of the caller.
   */
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external virtual {
    //* Params validation
    // Required
    if (random == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    // Optional
    // Default values if not provided
    if (methods == bytes32(0)) {
      methods = DEFAULT_DID_METHODS;
    }
    //* Implementation
    bytes32 id = keccak256(abi.encodePacked(methods, random, tx.origin, block.prevrandao));
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    if (!_isExpired(idHash)) {
      revert DidAlreadyExists();
    }
    _removeAllVms(idHash);
    _removeAllServices(idHash);
    (, bytes32 positionHash) = _createVm(
      CreateVmCommand({
        didHash: idHash,
        id: vmId,
        type_: [bytes32(0), bytes32(0)],
        publicKeyMultibase: "", // Empty - using ethereumAddress for auth
        blockchainAccountId: "", // Empty CAIP-10 string
        ethereumAddress: tx.origin,
        relationships: bytes1(0x01), // 0x01 (Authentication)
        expiration: 1 // Just to avoid one if statement
      })
    );
    _validateVm(positionHash, 0, tx.origin);
    updateExpiration({ idHash: idHash, forceExpire: false });
    emit DidCreated(id, idHash);
  }

  function createVm(DidCreateVmCommand memory command) external {
    //* Params validation
    // Required
    if (
      command.methods == bytes32(0) || command.senderId == bytes32(0) || command.targetId == bytes32(0)
        || command.relationships == bytes1(0)
    ) {
      revert MissingRequiredParameter();
    }
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget({
      methods: command.methods, senderId: command.senderId, senderVmId: command.senderVmId, targetId: command.targetId
    });
    _createVm(
      CreateVmCommand({
        didHash: targetIdHash,
        id: command.vmId,
        type_: command.type_,
        publicKeyMultibase: command.publicKeyMultibase,
        blockchainAccountId: command.blockchainAccountId,
        ethereumAddress: command.ethereumAddress,
        relationships: command.relationships,
        expiration: command.expiration
      })
    );
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function validateVm(bytes32 positionHash, uint256 expiration) external {
    _validateVm(positionHash, expiration, msg.sender);
  }

  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId) external {
    //* Params validation
    // Required
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _expireVm(targetIdHash, vmId);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    //* Params validation
    // Required
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    emit DidDeactivated(targetIdHash);
    updateExpiration({ idHash: targetIdHash, forceExpire: true });
  }

  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    //* Params validation
    // Required
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    //* Implementation
    bytes32 senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    bytes32 targetIdHash = HashUtils.calculateIdHash(methods, targetId);

    // CRITICAL: Target must be DEACTIVATED (expiration == 0), not just expired
    if (_expirationDate[targetIdHash] != 0) {
      revert DidNotDeactivated();
    }

    // Handle self-reactivation vs controller-reactivation differently
    if (senderIdHash == targetIdHash) {
      // Self-reactivation: owner reactivating their own deactivated DID
      // Skip DID expiration check (it's deactivated), but validate VM ownership
      if (!_isVmOwner(senderIdHash, senderVmId, tx.origin)) {
        revert NotAuthenticatedAsSenderId();
      }
    } else {
      // Controller reactivation: another DID is reactivating the target
      // Sender's DID must be active (not expired/deactivated)
      if (_isExpired(senderIdHash)) {
        revert DidExpired();
      }

      // Sender must be authenticated with a valid VM
      if (!_isAuthenticated(senderIdHash, senderVmId, tx.origin)) {
        revert NotAuthenticatedAsSenderId();
      }

      // Sender must be controller of target
      if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
        revert NotAControllerforTargetId();
      }
    }

    // Reactivate: set expiration to 4 years from now
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
    emit DidReactivated(targetIdHash);
  }

  function updateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external {
    //* Params validation
    // Required (controllerId can be bytes32(0) for removal)
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    //* Implementation
    (bytes32 senderIdHash, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    // Sender can make changes to this DID
    // If controller position is greater than MAX_LENGTH, always overwrite the last controller
    if (controllerPosition > CONTROLLERS_MAX_LENGTH - 1) {
      controllerPosition = CONTROLLERS_MAX_LENGTH - 1;
    }
    // Update the controllers mapping
    _controllers[targetIdHash][controllerPosition] = Controller(controllerId, controllerVmId);
    // Emit the ControllerUpdated event
    emit ControllerUpdated(senderIdHash, targetIdHash, controllerPosition, controllerVmId);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function updateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external {
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _updateService(targetIdHash, serviceId, type_, serviceEndpoint);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function updateExpiration(bytes32 idHash, bool forceExpire) internal {
    _expirationDate[idHash] = forceExpire ? 0 : block.timestamp + EXPIRATION;
  }

  //* View functions

  function getExpiration(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (uint256 exp) {
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    if (vmId != bytes32(0)) {
      return _getExpirationVm(idHash, vmId);
    } else {
      return _expirationDate[idHash];
    }
  }

  function authenticate(bytes32 methods, bytes32 id, bytes32 vmId, address sender) external view returns (bool) {
    return isVmRelationship(methods, id, vmId, 0x01, sender);
  }

  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    public
    view
    returns (bool)
  {
    if (methods == bytes32(0) || id == bytes32(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    // Check if DID is expired/deactivated before checking VM relationship
    if (_isExpired(idHash)) {
      revert DidExpired();
    }
    return _isVmRelationship(idHash, vmId, relationship, sender);
  }

  function getControllerList(bytes32 methods, bytes32 id)
    external
    view
    returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllers)
  {
    return _controllers[HashUtils.calculateIdHash(methods, id)];
  }

  function getVm(bytes32 methods, bytes32 id, bytes32 vmId, uint8 position)
    external
    view
    returns (VerificationMethod memory vm)
  {
    return _getVm(HashUtils.calculateIdHash(methods, id), vmId, position);
  }

  function getVmListLength(bytes32 methods, bytes32 id) external view returns (uint8) {
    return _getVmListLength(HashUtils.calculateIdHash(methods, id));
  }

  function getService(bytes32 methods, bytes32 id, bytes32 serviceId, uint8 position)
    external
    view
    returns (Service memory service)
  {
    return _getService(HashUtils.calculateIdHash(methods, id), serviceId, position);
  }

  function getServiceListLength(bytes32 methods, bytes32 id) external view returns (uint8 length) {
    return _getServiceListLength(HashUtils.calculateIdHash(methods, id));
  }

  //* Internal functions

  function _validateSenderAndTarget(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId)
    internal
    view
    returns (bytes32 senderIdHash, bytes32 targetIdHash)
  {
    // Calculate the hash of the sender and target DIDs
    senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    targetIdHash = HashUtils.calculateIdHash(methods, targetId);
    // Check if the DIDs are expired
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) {
      revert DidExpired();
    }
    // Check if the sender is authenticated as the sender DID
    if (!_isAuthenticated(senderIdHash, senderVmId, tx.origin)) {
      revert NotAuthenticatedAsSenderId();
    }
    // Check if the sender is a controller for the target DID
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
      revert NotAControllerforTargetId();
    }
  }

  function _isControllerFor(bytes32 senderDid, bytes32 senderVmId, bytes32 senderIdHash, bytes32 targetIdHash)
    internal
    view
    returns (bool)
  {
    bool controllersIsEmpty = true;
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      Controller storage ctrl = _controllers[targetIdHash][i];
      bytes32 ctrlId = ctrl.id;
      if (ctrlId != bytes32(0)) {
        controllersIsEmpty = false;
        bytes32 ctrlVmId = ctrl.vmId;
        if (ctrlVmId != bytes32(0)) {
          if (ctrlVmId == senderVmId && ctrlId == senderDid) {
            return true;
          }
        } else if (ctrlId == senderDid) {
          return true;
        }
      }
    }
    // If controllers array is empty and sender is the target, return true (controllers not used)
    if (controllersIsEmpty && senderIdHash == targetIdHash) {
      return true;
    }
    return false;
  }

  /**
   * @dev Checks if a given ID hash is expired.
   * @param idHash The hash of the ID to check.
   * @return expired True if the ID is expired, false otherwise.
   */
  function _isExpired(bytes32 idHash) internal view returns (bool expired) {
    uint256 exp = _expirationDate[idHash];
    return exp == 0 || block.timestamp > exp;
  }
}
