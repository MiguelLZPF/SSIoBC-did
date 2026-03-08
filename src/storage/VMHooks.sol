// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

/// @title VMHooks
/// @author Miguel Gomez Carpena
/// @dev Abstract hook declarations shared by VMStorage variants and DidAggregate.
/// Avoids diamond inheritance conflicts — both storage and aggregate inherit from this single ancestor.
/// Each VMStorage variant (full W3C / Ethereum-native) implements these hooks with its own storage layout.
/// DidAggregate calls hooks without knowing which variant is in use (Template Method pattern).
abstract contract VMHooks {
  /// @dev Checks if sender is authenticated (has authentication relationship + valid VM).
  /// @param didHash The hash of the DID.
  /// @param vmId The identifier of the Verification Method.
  /// @param sender The EOA address to verify.
  /// @return True if sender is authenticated for this DID via the given VM.
  function _isAuthenticated(bytes32 didHash, bytes32 vmId, address sender) internal view virtual returns (bool);

  /// @dev Checks if sender owns a VM with authentication, without checking VM expiration.
  /// Used for self-reactivation of deactivated DIDs where VMs are preserved but DID is inactive.
  /// @param didHash The hash of the DID.
  /// @param vmId The identifier of the Verification Method.
  /// @param sender The EOA address to verify ownership.
  /// @return True if sender owns the VM with authentication relationship.
  function _isVmOwner(bytes32 didHash, bytes32 vmId, address sender) internal view virtual returns (bool);

  /// @dev Checks if sender holds a specific W3C relationship on a VM.
  /// @param didHash The hash of the DID.
  /// @param id The identifier of the Verification Method.
  /// @param relationship The W3C relationship bitmask to check (0x01-0x1F).
  /// @param sender The EOA address to verify.
  /// @return True if sender has the specified relationship on the VM.
  function _isVmRelationship(bytes32 didHash, bytes32 id, bytes1 relationship, address sender)
    internal
    view
    virtual
    returns (bool);

  /// @dev Removes all VMs associated with a DID (used during DID re-creation).
  /// @param didHash The hash of the DID whose VMs should be removed.
  function _removeAllVms(bytes32 didHash) internal virtual;

  /// @dev Validates a VM by setting its expiration timestamp (completes the two-phase creation).
  /// @param positionHash The position hash assigned during VM creation.
  /// @param expiration The expiration timestamp to set (0 = use default).
  /// @param sender The EOA address that must match the VM's ethereumAddress.
  /// @return The VM identifier that was validated.
  function _validateVm(bytes32 positionHash, uint256 expiration, address sender) internal virtual returns (bytes32);

  /// @dev Expires a VM by setting its expiration to the current block timestamp.
  /// @param didHash The hash of the DID.
  /// @param id The identifier of the VM to expire.
  function _expireVm(bytes32 didHash, bytes32 id) internal virtual;

  /// @dev Returns the expiration timestamp of a specific VM.
  /// @param didHash The hash of the DID.
  /// @param id The identifier of the VM.
  /// @return The expiration timestamp of the VM.
  function _getExpirationVm(bytes32 didHash, bytes32 id) internal view virtual returns (uint256);

  /// @dev Returns the number of VMs associated with a DID.
  /// @param didHash The hash of the DID.
  /// @return The count of VMs.
  function _getVmListLength(bytes32 didHash) internal view virtual returns (uint8);

  /// @dev Returns VM fields needed for authorization checks (non-reverting).
  /// Returns zero values for non-existent VMs, allowing the caller to handle gracefully.
  /// @param idHash The hash of the DID.
  /// @param vmId The identifier of the VM.
  /// @return expiration The VM's expiration timestamp.
  /// @return ethereumAddress The VM's associated Ethereum address.
  /// @return relationships The VM's W3C relationship bitmask.
  function _getVmForAuth(bytes32 idHash, bytes32 vmId)
    internal
    view
    virtual
    returns (uint256 expiration, address ethereumAddress, bytes1 relationships);
}
