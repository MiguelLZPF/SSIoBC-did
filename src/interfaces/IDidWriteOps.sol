// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

/// @title IDidWriteOps
/// @author Miguel Gomez Carpena
/// @notice Write DID operations (ISP: Interface Segregation Principle)
interface IDidWriteOps {
  /// @dev Emitted when a new DID is created.
  event DidCreated(bytes32 indexed id, bytes32 indexed idHash);

  /// @dev Emitted when the controller of a DID is updated.
  event ControllerUpdated(
    bytes32 indexed senderDidHash, bytes32 indexed targetDidHash, uint8 controllerPosition, bytes32 vmId
  );

  /// @dev Emitted when a DID is deactivated (permanently expired).
  event DidDeactivated(bytes32 indexed targetDidHash);

  /// @dev Emitted when a deactivated DID is reactivated.
  event DidReactivated(bytes32 indexed targetDidHash);

  /// @dev Creates a new DID.
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external;

  /// @dev Validates a Verification Method (VM).
  function validateVm(bytes32 positionHash, uint256 expiration) external;

  /// @dev Expires a Verification Method (VM).
  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId) external;

  /// @dev Deactivates a DID permanently.
  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external;

  /// @dev Reactivates a deactivated DID.
  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external;

  /// @dev Updates the controller of the DID manager.
  function updateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external;

  /// @dev Updates, creates or removes a service for a given ID.
  function updateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external;
}
