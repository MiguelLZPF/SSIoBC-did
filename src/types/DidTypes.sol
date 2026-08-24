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

/// @dev Default DID methods: segment 0 = "lzpf", segment 1 = "main", segment 2 = empty.
/// ";" (0x3B) is the segment filler, chosen over 0x00 so that a deliberately empty segment is
/// distinguishable from an unset one and so the literal stays readable. It is an internal
/// encoding detail: `W3CResolverUtils.trimMethodSegment` strips it (and 0x00) before the DID
/// string is built, because neither is legal under the W3C DID Core v1.0 ABNF. See PROJECT.md,
/// "Segment Filler: Why ; and Not 0x00".
bytes32 constant DEFAULT_DID_METHODS = bytes32("lzpf;;;;;;main;;;;;;;;;;;;;;;;;;");
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
error DirectEOACallRequired();
