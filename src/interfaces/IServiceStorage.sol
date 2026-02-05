// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

// =========================================================================
// Constants
// =========================================================================

bytes32 constant SERVICE_NAMESPACE = bytes32("service");

// Max lengths for dynamic bytes (optimized for typical W3C services)
// Supports multiple type names with delimiter (e.g., "LinkedDomains\x00DIDCommMessaging")
uint256 constant MAX_SERVICE_TYPE_LENGTH = 500;
// Supports long URLs with query params (e.g., "https://example.com/api/v2/credentials?issuer=...")
uint256 constant MAX_SERVICE_ENDPOINT_LENGTH = 2000;

// =========================================================================
// Structs
// =========================================================================

/**
 * @dev Service struct optimized for gas efficiency.
 * Uses dynamic bytes for flexible storage following VMStorage v1.0 pattern.
 * - type_: Packed service types with '\x00' delimiter (e.g., "LinkedDomains\x00DIDCommMessaging")
 * - serviceEndpoint: Packed endpoints with '\x00' delimiter (e.g., "https://a.com\x00https://b.com")
 */
struct Service {
  bytes32 id;
  bytes type_; // Packed types with '\x00' delimiter
  bytes serviceEndpoint; // Packed endpoints with '\x00' delimiter
}

interface IServiceStorage {
  // =========================================================================
  // Events
  // =========================================================================

  /**
   * @dev Emitted when a service is created, updated, or deleted for a DID.
   * @param didIdHash The unique identifier hash of the DID.
   * @param id The unique identifier of the service.
   * @param serviceIdHash The unique identifier hash of the service.
   * @param positionHash The hash of the position of the service (0 for deletion).
   */
  event ServiceUpdated(
    bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed serviceIdHash, bytes32 positionHash
  );

  // =========================================================================
  // Errors
  // =========================================================================

  /// @dev Thrown when service type bytes exceed MAX_SERVICE_TYPE_LENGTH
  error ServiceTypeTooLarge();

  /// @dev Thrown when service endpoint bytes exceed MAX_SERVICE_ENDPOINT_LENGTH
  error ServiceEndpointTooLarge();

  /// @dev Thrown when service ID is bytes32(0)
  error ServiceIdCannotBeZero();

  /// @dev Thrown when service type is empty on create/update
  error ServiceTypeCannotBeEmpty();

  /// @dev Thrown when service endpoint is empty on create/update
  error ServiceEndpointCannotBeEmpty();
}
