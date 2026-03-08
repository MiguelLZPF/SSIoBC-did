// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

/// @title IDidAuth
/// @author Miguel Gomez Carpena
/// @notice DID authentication operations (ISP: Interface Segregation Principle)
interface IDidAuth {
  /// @notice Checks if sender is authorized to act on targetId with the given VM relationship.
  function isAuthorized(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) external view returns (bool authorized);

  /// @dev Checks if there is a VM relationship.
  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    external
    view
    returns (bool);
}
