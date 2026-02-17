// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev Struct representing a controller of a DID.
 */
struct Controller {
  bytes32 id; // The unique identifier of the controller's DID.
  bytes32 vmId; // (optional) The unique identifier of the controller's VM.
}

bytes32 constant DEFAULT_DID_METHODS = bytes32("lzpf;;;;;;main;;;;;;;;;;;;;;;;;;"); // ";" is the null or escape
// character
uint256 constant EXPIRATION = 126144000; // 4 years in seconds (4 * 365 * 24 * 60 * 60)
uint8 constant CONTROLLERS_MAX_LENGTH = 5;

// File-level error declarations shared by DidManager and DidManagerNative
error DidAlreadyExists();
error DidExpired();
error NotAuthenticatedAsSenderId();
error NotAControllerforTargetId();
error DidNotDeactivated();

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
}
