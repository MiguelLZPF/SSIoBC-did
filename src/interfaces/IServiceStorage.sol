// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

// Re-export types from ServiceTypes.sol — allows consumers to import types alongside the interface
// (e.g., `import { IServiceStorage, Service } from "@interfaces/IServiceStorage.sol"`)
// Canonical source: @types/ServiceTypes.sol
import {
  Service,
  SERVICE_NAMESPACE,
  MAX_SERVICE_TYPE_LENGTH,
  MAX_SERVICE_ENDPOINT_LENGTH
} from "@types/ServiceTypes.sol";

/// @title IServiceStorage
/// @author Miguel Gomez Carpena
/// @notice Interface for service endpoint storage
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

  /// @dev Thrown when adding a new service would push the list past 255 entries. Service positions are `uint8`
  /// (`getServiceListLength` and `getService` take and return `uint8` in the ABI), so a 256th entry would wrap its
  /// position to 0 and make the list length untruthful. The cap keeps the existing ABI instead of widening it.
  error TooManyServices();
}
