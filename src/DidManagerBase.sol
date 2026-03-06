// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import {
  Controller,
  DEFAULT_DID_METHODS,
  EXPIRATION,
  CONTROLLERS_MAX_LENGTH,
  DidAlreadyExists,
  DidExpired,
  MissingRequiredParameter,
  NotAuthenticatedAsSenderId,
  NotAControllerforTargetId,
  DidNotDeactivated
} from "./interfaces/IDidManagerBase.sol";

/**
 * @title DidManagerBase
 * @author Miguel Gómez Carpena
 * @dev Abstract base contract for shared DID lifecycle logic.
 * Provides expiration management and controller management.
 * Both DidManager (full W3C) and DidManagerNative (Ethereum-native) inherit from this.
 */
abstract contract DidManagerBase {
  // =========================================================================
  // Storage
  // =========================================================================

  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint256) internal _expirationDate;
  // hash(method0:method1:method2:id) --> controller[0..4]
  mapping(bytes32 => Controller[CONTROLLERS_MAX_LENGTH]) internal _controllers;

  // =========================================================================
  // Concrete functions
  // =========================================================================

  function updateExpiration(bytes32 idHash, bool forceExpire) internal {
    _expirationDate[idHash] = forceExpire ? 0 : block.timestamp + EXPIRATION;
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

  // =========================================================================
  // Parameter Validation Helpers
  // =========================================================================

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
