// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

// =========================================================================
// Structs
// =========================================================================

/**
 * @dev Struct representing a controller of a DID.
 */
struct Controller {
  bytes32 id; // The unique identifier of the controller's DID.
  bytes32 vmId; // (optional) The unique identifier of the controller's VM.
}

// =========================================================================
// Constants
// =========================================================================

bytes32 constant DEFAULT_DID_METHODS = bytes32("lzpf;;;;;;main;;;;;;;;;;;;;;;;;;"); // ";" is the null or escape
// character
uint256 constant EXPIRATION = 126144000; // 4 years in seconds (4 * 365 * 24 * 60 * 60)
uint8 constant CONTROLLERS_MAX_LENGTH = 5;

// =========================================================================
// Errors (shared by DidManager, DidManagerNative, VMStorage, VMStorageNative)
// =========================================================================

error DidAlreadyExists();
error DidExpired();
error MissingRequiredParameter();
error NotAuthenticatedAsSenderId();
error NotAControllerForTargetId();
error VmRelationshipOutOfRange();
error DidNotDeactivated();
