// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager } from "@interfaces/IDidManager.sol";
import { ServiceStorage } from "@storage/ServiceStorage.sol";
import { VMHooks } from "@storage/VMHooks.sol";
import { Service } from "@types/ServiceTypes.sol";
import { HashUtils } from "@src/HashUtils.sol";
import {
  Controller,
  EXPIRATION,
  CONTROLLERS_MAX_LENGTH,
  MissingRequiredParameter,
  DidExpired,
  NotAuthenticatedAsSenderId,
  NotAControllerForTargetId,
  DidNotDeactivated,
  VmRelationshipOutOfRange
} from "@types/DidTypes.sol";

/// @title DidAggregate
/// @author Miguel Gomez Carpena
/// @dev Abstract aggregate root: all shared DID lifecycle, auth, controllers, services.
/// Both DidManager (full W3C) and DidManagerNative (Ethereum-native) inherit from this.
/// Contains ALL shared logic — concrete managers only implement variant-specific functions.
/// VM hooks inherited from VMHooks (shared ancestor with VMStorage variants — no diamond).
abstract contract DidAggregate is IDidManager, ServiceStorage, VMHooks {
  // ═══════════════════════════════════════════════════════════════════
  // Storage
  // ═══════════════════════════════════════════════════════════════════

  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint256) internal _expirationDate;
  // hash(method0:method1:method2:id) --> controller[0..4]
  mapping(bytes32 => Controller[CONTROLLERS_MAX_LENGTH]) internal _controllers;

  // ═══════════════════════════════════════════════════════════════════
  // Shared write operations (IDidWriteOps — WRITTEN ONCE)
  // ═══════════════════════════════════════════════════════════════════

  function validateVm(bytes32 positionHash, uint256 expiration) external {
    _validateVm(positionHash, expiration, msg.sender);
  }

  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId) external {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _expireVm(targetIdHash, vmId);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    emit DidDeactivated(targetIdHash);
    updateExpiration({ idHash: targetIdHash, forceExpire: true });
  }

  /// @dev Reactivates a deactivated DID. Uses tx.origin intentionally for EOA identity verification:
  /// the DID system requires the actual signing EOA, preventing intermediary contracts from impersonating.
  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
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
        revert NotAControllerForTargetId();
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
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (bytes32 senderIdHash, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    // If controller position is greater than MAX_LENGTH, always overwrite the last controller
    if (controllerPosition > CONTROLLERS_MAX_LENGTH - 1) {
      controllerPosition = CONTROLLERS_MAX_LENGTH - 1;
    }
    // Update the controllers mapping
    _controllers[targetIdHash][controllerPosition] = Controller({ id: controllerId, vmId: controllerVmId });
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
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _updateService(targetIdHash, serviceId, type_, serviceEndpoint);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  // ═══════════════════════════════════════════════════════════════════
  // Shared auth (IDidAuth — WRITTEN ONCE)
  // ═══════════════════════════════════════════════════════════════════

  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    public
    view
    returns (bool)
  {
    _validateViewParams(methods, id, sender);
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    // Check if DID is expired/deactivated before checking VM relationship
    if (_isExpired(idHash)) {
      revert DidExpired();
    }
    return _isVmRelationship(idHash, vmId, relationship, sender);
  }

  /// @dev Checks if sender is authorized to act on targetId with the given VM relationship.
  /// Uses _getVmForAuth hook (variant-specific) to retrieve VM fields without depending on struct type.
  /// Non-reverting: returns false for expired DIDs or invalid VMs. Reverts only on invalid inputs.
  /// @param methods The DID methods (bytes32 with three 10-byte segments).
  /// @param senderId The ID of the sender's DID.
  /// @param senderVmId The ID of the sender's Verification Method.
  /// @param targetId The ID of the target DID.
  /// @param relationship The required W3C relationship bitmask (0x01-0x1F).
  /// @param sender The EOA address claiming ownership of the sender VM.
  /// @return True if sender is authorized; false otherwise.
  function isAuthorized(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) external view returns (bool) {
    // Revert on invalid inputs only
    _validateAuthorizedParams(methods, senderId, senderVmId, targetId, relationship, sender);
    if (relationship > bytes1(0x1F)) revert VmRelationshipOutOfRange();

    bytes32 senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    bytes32 targetIdHash = (senderId == targetId) ? senderIdHash : HashUtils.calculateIdHash(methods, targetId);

    // 1. Both DIDs must be active
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) return false;

    // 2. Sender's VM has the required relationship (non-reverting via _getVmForAuth)
    (uint256 vmExpiration, address vmEthereumAddress, bytes1 vmRelationships) = _getVmForAuth(senderIdHash, senderVmId);
    if (vmExpiration == 0 || vmExpiration <= block.timestamp) return false;
    if (vmEthereumAddress != sender || (vmRelationships & relationship) != relationship) return false;

    // 3. Sender is controller of target (or IS target for self-controlled)
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) return false;

    return true;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Shared read operations (IDidReadOps — WRITTEN ONCE)
  // ═══════════════════════════════════════════════════════════════════

  function getExpiration(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (uint256 exp) {
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    if (vmId != bytes32(0)) {
      return _getExpirationVm(idHash, vmId);
    } else {
      return _expirationDate[idHash];
    }
  }

  function getControllerList(bytes32 methods, bytes32 id)
    external
    view
    returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllers)
  {
    return _controllers[HashUtils.calculateIdHash(methods, id)];
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

  // ═══════════════════════════════════════════════════════════════════
  // Internal shared logic (absorbed from DidManagerBase)
  // ═══════════════════════════════════════════════════════════════════

  /// @dev Validates sender and target DIDs for authenticated operations.
  /// Changed from private to internal so thin managers can call from createVm().
  function _validateSenderAndTarget(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId)
    internal
    view
    returns (bytes32 senderIdHash, bytes32 targetIdHash)
  {
    senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    targetIdHash = (senderId == targetId) ? senderIdHash : HashUtils.calculateIdHash(methods, targetId);
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) {
      revert DidExpired();
    }
    if (!_isAuthenticated(senderIdHash, senderVmId, tx.origin)) {
      revert NotAuthenticatedAsSenderId();
    }
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
      revert NotAControllerForTargetId();
    }
  }

  /// @dev Updates the expiration timestamp for a DID. If forceExpire is true, sets expiration to 0 (deactivated).
  /// Otherwise, refreshes to EXPIRATION seconds from now (4 years).
  /// @param idHash The hash of the DID to update.
  /// @param forceExpire If true, deactivates the DID by setting expiration to 0.
  function updateExpiration(bytes32 idHash, bool forceExpire) internal {
    _expirationDate[idHash] = forceExpire ? 0 : block.timestamp + EXPIRATION;
  }

  /// @dev Checks if a given ID hash is expired.
  function _isExpired(bytes32 idHash) internal view returns (bool expired) {
    uint256 exp = _expirationDate[idHash];
    return exp == 0 || block.timestamp > exp;
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

  // ═══════════════════════════════════════════════════════════════════
  // Parameter Validation Helpers
  // ═══════════════════════════════════════════════════════════════════

  /// @dev Validates that methods, senderId, and targetId are non-zero.
  function _validateTripleParams(bytes32 methods, bytes32 senderId, bytes32 targetId) internal pure {
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
  }

  /// @dev Validates all six parameters for isAuthorized view.
  function _validateAuthorizedParams(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) internal pure {
    if (
      methods == bytes32(0) || senderId == bytes32(0) || senderVmId == bytes32(0) || targetId == bytes32(0)
        || relationship == bytes1(0) || sender == address(0)
    ) {
      revert MissingRequiredParameter();
    }
  }

  /// @dev Validates methods, id, and sender for view functions.
  function _validateViewParams(bytes32 methods, bytes32 id, address sender) internal pure {
    if (methods == bytes32(0) || id == bytes32(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
  }
}
