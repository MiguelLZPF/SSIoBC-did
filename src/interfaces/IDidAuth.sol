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

  /// @notice Verifies off-chain authorization via ECDSA signature recovery + authorization check.
  /// @dev Combines ecrecover with isAuthorized for gasless DID authentication via eth_call.
  function isAuthorizedOffChain(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    bytes32 messageHash,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external view returns (bool);

  /// @dev Checks if there is a VM relationship.
  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    external
    view
    returns (bool);
}
