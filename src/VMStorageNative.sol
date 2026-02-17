// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
  DEFAULT_VM_ID_NATIVE,
  DEFAULT_VM_EXPIRATION_NATIVE,
  MAX_PUBLIC_KEY_MULTIBASE_LENGTH_NATIVE,
  CreateVmCommand,
  VerificationMethod,
  IVMStorageNative
} from "./interfaces/IVMStorageNative.sol";
import { HashUtils } from "./HashUtils.sol";

/// @title VMStorageNative
/// @author Miguel Gómez Carpena
/// @notice Single-slot VM storage (Ethereum addresses)
abstract contract VMStorageNative is IVMStorageNative {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  //* Storage
  // Per DID hash, maintain the set of VM IDs (for O(1) add/remove/len/at)
  mapping(bytes32 => EnumerableSet.Bytes32Set) private _vmIds;
  // DID hash => VM ID => VerificationMethod (1 slot per VM)
  mapping(bytes32 => mapping(bytes32 => VerificationMethod)) private _vmByNsAndId;
  // positionHash => VM ID (to support validateVm(positionHash, ...))
  mapping(bytes32 => bytes32) private _vmIdByPositionHash;
  // positionHash => DID hash (so we can locate payload by namespace)
  mapping(bytes32 => bytes32) private _didHashByPositionHash;
  // DID hash => VM ID => positionHash (for cleanup)
  mapping(bytes32 => mapping(bytes32 => bytes32)) private _positionHashByDidAndId;
  // DID hash => VM ID => publicKeyMultibase (overflow storage, only for keyAgreement VMs)
  mapping(bytes32 => mapping(bytes32 => bytes)) private _publicKeyMultibase;

  /**
   * @dev Creates a new native verification method (1 slot).
   * @param command The command containing the parameters for creating the VM.
   */
  function _createVm(CreateVmCommand memory command) internal returns (bytes32 idHash, bytes32 positionHash) {
    //* Params validation
    if (command.ethereumAddress == address(0)) revert EthereumAddressRequired();

    // publicKeyMultibase <=> keyAgreement enforcement
    bool hasKeyAgreement = (command.relationships & 0x04) == 0x04;
    if (hasKeyAgreement) {
      if (command.publicKeyMultibase.length == 0) revert PublicKeyMultibaseRequiredForKeyAgreement();
      if (command.publicKeyMultibase[0] != "z") revert InvalidMultibasePrefix();
      if (command.publicKeyMultibase.length > MAX_PUBLIC_KEY_MULTIBASE_LENGTH_NATIVE) revert PublicKeyTooLarge();
    } else {
      if (command.publicKeyMultibase.length != 0) revert PublicKeyMultibaseNotAllowedWithoutKeyAgreement();
    }

    // Optional defaults
    if (command.id == bytes32(0)) {
      command.id = DEFAULT_VM_ID_NATIVE;
    }

    //* Implementation
    // Existence check
    if (_vmIds[command.didHash].contains(command.id)) revert VmAlreadyExists();
    // Add ID to set and compute position
    bool added = _vmIds[command.didHash].add(command.id);
    assert(added);
    uint256 vmCount = _vmIds[command.didHash].length();
    if (vmCount > type(uint8).max) revert TooManyVerificationMethods();
    uint8 position = uint8(vmCount);
    idHash = HashUtils.calculateIdHash(command.didHash, command.id);
    positionHash = HashUtils.calculatePositionHash(command.didHash, position);

    // Store VM (1 slot)
    _vmByNsAndId[command.didHash][command.id] = VerificationMethod({
      ethereumAddress: command.ethereumAddress,
      relationships: command.relationships,
      expiration: 0 // Needs validation via _validateVm
    });

    // Store publicKeyMultibase in overflow mapping (only for keyAgreement VMs)
    if (hasKeyAgreement) {
      _publicKeyMultibase[command.didHash][command.id] = command.publicKeyMultibase;
    }

    // Map position hash to ID and DID for validateVm lookup and cleanup
    _vmIdByPositionHash[positionHash] = command.id;
    _didHashByPositionHash[positionHash] = command.didHash;
    _positionHashByDidAndId[command.didHash][command.id] = positionHash;

    // Event
    emit VmCreated(command.didHash, command.id, idHash, positionHash);
    return (idHash, positionHash);
  }

  /**
   * @dev Validates a specific VM by setting its expiration timestamp.
   * @param positionHash The hash of the VM position.
   * @param expiration The expiration timestamp to set.
   * @param sender The address of the sender.
   * @return id The identifier of the validated VM.
   */
  function _validateVm(bytes32 positionHash, uint256 expiration, address sender) internal returns (bytes32 id) {
    if (expiration == 0) {
      expiration = block.timestamp + DEFAULT_VM_EXPIRATION_NATIVE;
    }
    bytes32 vmId = _vmIdByPositionHash[positionHash];
    bytes32 didHash = _didHashByPositionHash[positionHash];
    VerificationMethod storage vm = _vmByNsAndId[didHash][vmId];
    if (vm.ethereumAddress == address(0)) revert VmNotFound();
    if (vm.expiration != 0) revert VmAlreadyValidated();
    if (vm.ethereumAddress != sender) revert InvalidSignature();
    vm.expiration = uint88(expiration);
    emit VmValidated(vmId);
    return vmId;
  }

  /**
   * @dev Expires a specific VM by setting its expiration to current block timestamp.
   * @param didHash The hash of the DID.
   * @param id The identifier of the VM to expire.
   */
  function _expireVm(bytes32 didHash, bytes32 id) internal {
    VerificationMethod storage vm = _vmByNsAndId[didHash][id];
    if (vm.expiration <= block.timestamp) revert VmAlreadyExpired();
    vm.expiration = uint88(block.timestamp);
    emit VmExpirationUpdated(didHash, id, true, vm.expiration);
  }

  function _removeAllVms(bytes32 didHash) internal {
    uint256 len = _vmIds[didHash].length();
    while (len > 0) {
      bytes32 lastId = _vmIds[didHash].at(len - 1);
      // Delete publicKeyMultibase overflow (no-op for non-keyAgreement VMs)
      delete _publicKeyMultibase[didHash][lastId];
      // Delete VM payload
      delete _vmByNsAndId[didHash][lastId];
      // Delete positionHash mappings
      bytes32 storedPositionHash = _positionHashByDidAndId[didHash][lastId];
      delete _positionHashByDidAndId[didHash][lastId];
      delete _vmIdByPositionHash[storedPositionHash];
      delete _didHashByPositionHash[storedPositionHash];
      // Remove from set
      _vmIds[didHash].remove(lastId);
      len--;
    }
  }

  /**
   * @dev Retrieves a specific native VM.
   * @param didHash The hash of the DID.
   * @param id The identifier of the VM.
   * @param position The position of the VM.
   * @return vm The VerificationMethod struct.
   */
  function _getVm(bytes32 didHash, bytes32 id, uint8 position) internal view returns (VerificationMethod memory vm) {
    if (id == bytes32(0)) {
      uint256 len = _vmIds[didHash].length();
      if (position == 0 || uint256(position) > len) {
        return vm; // empty
      }
      bytes32 atId = _vmIds[didHash].at(uint256(position) - 1);
      return _vmByNsAndId[didHash][atId];
    }
    return _vmByNsAndId[didHash][id];
  }

  function _getVmListLength(bytes32 didHash) internal view returns (uint8) {
    return uint8(_vmIds[didHash].length());
  }

  function _getExpirationVm(bytes32 didHash, bytes32 id) internal view returns (uint256 exp) {
    return _vmByNsAndId[didHash][id].expiration;
  }

  /**
   * @dev Returns the VM ID at a given position in the EnumerableSet.
   * Used by W3CResolverNative to get VM IDs for W3C document construction.
   * @param didHash The hash of the DID.
   * @param position The 1-based position.
   * @return The VM ID at that position, or bytes32(0) if out of bounds.
   */
  function _getVmIdAtPosition(bytes32 didHash, uint8 position) internal view returns (bytes32) {
    uint256 len = _vmIds[didHash].length();
    if (position == 0 || uint256(position) > len) {
      return bytes32(0);
    }
    return _vmIds[didHash].at(uint256(position) - 1);
  }

  /**
   * @dev Checks if the given sender is authenticated for the specified DID hash and VM ID.
   */
  function _isAuthenticated(bytes32 didHash, bytes32 vmId, address sender) internal view returns (bool) {
    return _isVmRelationship(didHash, vmId, 0x01, sender);
  }

  /**
   * @dev Checks if the given sender owns a VM with authentication relationship, without checking expiration.
   * Used for self-reactivation of deactivated DIDs.
   */
  function _isVmOwner(bytes32 didHash, bytes32 vmId, address sender) internal view returns (bool) {
    if (vmId == bytes32(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
    VerificationMethod memory vm = _vmByNsAndId[didHash][vmId];
    if (vm.ethereumAddress == address(0)) return false;
    return (vm.ethereumAddress == sender && (vm.relationships & bytes1(0x01)) == bytes1(0x01));
  }

  /**
   * @dev Returns the publicKeyMultibase for a native VM. Empty for non-keyAgreement VMs.
   */
  function _getPublicKeyMultibase(bytes32 didHash, bytes32 vmId) internal view returns (bytes memory) {
    return _publicKeyMultibase[didHash][vmId];
  }

  /**
   * @dev Checks if the given sender is in the specified relationship for the specified DID hash and VM ID.
   */
  function _isVmRelationship(bytes32 didHash, bytes32 id, bytes1 relationship, address sender)
    internal
    view
    returns (bool)
  {
    if (id == bytes32(0) || relationship == bytes1(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
    if (relationship > bytes1(0x1F)) revert VmRelationshipOutOfRange();
    VerificationMethod memory vm = _vmByNsAndId[didHash][id];
    if (vm.expiration == 0 || vm.expiration <= block.timestamp) revert VmAlreadyExpired();
    return (vm.ethereumAddress == sender && (vm.relationships & relationship) == relationship);
  }
}
