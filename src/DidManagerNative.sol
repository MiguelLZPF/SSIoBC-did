// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManagerNative, CreateVmCommand as NativeCreateVmCommand } from "@src/interfaces/IDidManagerNative.sol";
import { VMStorageNative, VerificationMethod, CreateVmCommand } from "@src/VMStorageNative.sol";
import { ServiceStorage } from "@src/ServiceStorage.sol";
import { Service } from "@src/interfaces/IServiceStorage.sol";
import { HashUtils } from "@src/HashUtils.sol";
import {
  DidManagerBase,
  Controller,
  DEFAULT_DID_METHODS,
  CONTROLLERS_MAX_LENGTH,
  DidAlreadyExists,
  DidExpired,
  NotAuthenticatedAsSenderId,
  NotAControllerforTargetId,
  DidNotDeactivated
} from "@src/DidManagerBase.sol";

/**
 * @title DidManagerNative
 * @author Miguel Gómez Carpena
 * @dev Ethereum-native DID manager with 1-slot VM storage.
 * Stores only ethereumAddress + relationships + expiration per VM.
 * W3C fields (type_, publicKeyMultibase, blockchainAccountId) are derived at resolution time.
 */
contract DidManagerNative is IDidManagerNative, VMStorageNative, DidManagerBase, ServiceStorage {
  /**
   * @dev Creates a new Ethereum-native DID.
   */
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external virtual {
    if (random == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    if (methods == bytes32(0)) {
      methods = DEFAULT_DID_METHODS;
    }
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
        ethereumAddress: tx.origin,
        relationships: bytes1(0x01), // Authentication
        publicKeyMultibase: "" // No keyAgreement on default VM
      })
    );
    _validateVm(positionHash, 0, tx.origin);
    updateExpiration({ idHash: idHash, forceExpire: false });
    emit DidCreated(id, idHash);
  }

  function createVm(NativeCreateVmCommand memory command) external {
    if (
      command.methods == bytes32(0) || command.senderId == bytes32(0) || command.targetId == bytes32(0)
        || command.relationships == bytes1(0)
    ) {
      revert MissingRequiredParameter();
    }
    (, bytes32 targetIdHash) = _validateSenderAndTarget({
      methods: command.methods, senderId: command.senderId, senderVmId: command.senderVmId, targetId: command.targetId
    });
    _createVm(
      CreateVmCommand({
        didHash: targetIdHash,
        id: command.vmId,
        ethereumAddress: command.ethereumAddress,
        relationships: command.relationships,
        publicKeyMultibase: command.publicKeyMultibase
      })
    );
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function validateVm(bytes32 positionHash, uint256 expiration) external {
    _validateVm(positionHash, expiration, msg.sender);
  }

  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId) external {
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _expireVm(targetIdHash, vmId);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    emit DidDeactivated(targetIdHash);
    updateExpiration({ idHash: targetIdHash, forceExpire: true });
  }

  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    bytes32 senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    bytes32 targetIdHash = HashUtils.calculateIdHash(methods, targetId);

    if (_expirationDate[targetIdHash] != 0) {
      revert DidNotDeactivated();
    }

    if (senderIdHash == targetIdHash) {
      if (!_isVmOwner(senderIdHash, senderVmId, tx.origin)) {
        revert NotAuthenticatedAsSenderId();
      }
    } else {
      if (_isExpired(senderIdHash)) {
        revert DidExpired();
      }
      if (!_isAuthenticated(senderIdHash, senderVmId, tx.origin)) {
        revert NotAuthenticatedAsSenderId();
      }
      if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
        revert NotAControllerforTargetId();
      }
    }

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
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    (bytes32 senderIdHash, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    if (controllerPosition > CONTROLLERS_MAX_LENGTH - 1) {
      controllerPosition = CONTROLLERS_MAX_LENGTH - 1;
    }
    _controllers[targetIdHash][controllerPosition] = Controller({ id: controllerId, vmId: controllerVmId });
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
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _updateService(targetIdHash, serviceId, type_, serviceEndpoint);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  //* Internal helpers

  function _validateSenderAndTarget(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId)
    private
    view
    returns (bytes32 senderIdHash, bytes32 targetIdHash)
  {
    senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    targetIdHash = HashUtils.calculateIdHash(methods, targetId);
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) {
      revert DidExpired();
    }
    if (!_isAuthenticated(senderIdHash, senderVmId, tx.origin)) {
      revert NotAuthenticatedAsSenderId();
    }
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
      revert NotAControllerforTargetId();
    }
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

  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    public
    view
    returns (bool)
  {
    if (methods == bytes32(0) || id == bytes32(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    if (_isExpired(idHash)) {
      revert DidExpired();
    }
    return _isVmRelationship(idHash, vmId, relationship, sender);
  }

  /// @inheritdoc IDidManagerNative
  function isAuthorized(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) external view returns (bool) {
    // Revert on invalid inputs only
    if (
      methods == bytes32(0) || senderId == bytes32(0) || senderVmId == bytes32(0) || targetId == bytes32(0)
        || relationship == bytes1(0) || sender == address(0)
    ) {
      revert MissingRequiredParameter();
    }
    if (relationship > bytes1(0x1F)) revert VmRelationshipOutOfRange();

    bytes32 senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    bytes32 targetIdHash = HashUtils.calculateIdHash(methods, targetId);

    // 1. Both DIDs must be active
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) return false;

    // 2. Sender's VM has the required relationship (non-reverting via _getVm)
    VerificationMethod memory senderVm = _getVm(senderIdHash, senderVmId, 0);
    if (senderVm.expiration == 0 || senderVm.expiration <= block.timestamp) return false;
    if (senderVm.ethereumAddress != sender || (senderVm.relationships & relationship) != relationship) return false;

    // 3. Sender is controller of target (or IS target for self-controlled)
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) return false;

    return true;
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

  function getVmPublicKeyMultibase(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (bytes memory) {
    return _getPublicKeyMultibase(HashUtils.calculateIdHash(methods, id), vmId);
  }

  function getVmIdAtPosition(bytes32 methods, bytes32 id, uint8 position) external view returns (bytes32) {
    return _getVmIdAtPosition(HashUtils.calculateIdHash(methods, id), position);
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
}
