// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
  DEFAULT_VM_ID,
  DEFAULT_VM_EXPIRATION,
  DEFAULT_VM_TYPE_0,
  DEFAULT_VM_TYPE_1,
  MAX_PUBLIC_KEY_MULTIBASE_LENGTH,
  MAX_BLOCKCHAIN_ACCOUNT_ID_LENGTH,
  CreateVmCommand,
  VerificationMethod,
  IVMStorage
} from "./interfaces/IVMStorage.sol";

abstract contract VMStorage is IVMStorage {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  //* Storage
  // Per DID hash, maintain the set of VM IDs (for O(1) add/remove/len/at)
  mapping(bytes32 => EnumerableSet.Bytes32Set) private _vmIds;
  // DID hash => VM ID => VerificationMethod
  mapping(bytes32 => mapping(bytes32 => VerificationMethod)) private _vmByNsAndId;
  // positionHash => VM ID (to support validateVm(positionHash, ...))
  mapping(bytes32 => bytes32) private _vmIdByPositionHash;
  // positionHash => DID hash (so we can locate payload by namespace)
  mapping(bytes32 => bytes32) private _didHashByPositionHash;
  // DID hash => VM ID => positionHash (for cleanup)
  mapping(bytes32 => mapping(bytes32 => bytes32)) private _positionHashByDidAndId;

  /**
   * @dev Creates a new verification method.
   * @param command The command containing the parameters for creating the verification method.
   * @dev command.publicKeyMultibase, command.blockchainAccountId OR command.ethereumAddress are required.
   */
  function _createVm(CreateVmCommand memory command) internal returns (bytes32 idHash, bytes32 positionHash) {
    //* Params validation
    // Length validation for dynamic bytes
    if (command.publicKeyMultibase.length > MAX_PUBLIC_KEY_MULTIBASE_LENGTH) revert PublicKeyTooLarge();
    if (command.blockchainAccountId.length > MAX_BLOCKCHAIN_ACCOUNT_ID_LENGTH) revert BlockchainAccountIdTooLarge();

    // Required: at least one identification method
    if (
      command.publicKeyMultibase.length == 0 && command.blockchainAccountId.length == 0
        && command.ethereumAddress == address(0)
    ) {
      revert PubKeyBlockchainAccountORAddressRequired();
    }

    // Multibase prefix validation: if public key provided, must start with 'z' (base58btc)
    if (command.publicKeyMultibase.length > 0 && command.publicKeyMultibase[0] != "z") {
      revert InvalidMultibasePrefix();
    }

    // Optional defaults
    if (command.id == bytes32(0)) {
      command.id = DEFAULT_VM_ID; // "vm-0"
    }
    if (command.type_[0] == bytes32(0)) {
      command.type_ = [DEFAULT_VM_TYPE_0, DEFAULT_VM_TYPE_1]; // "EcdsaSecp256k1VerificationKey20", "19"
    }
    if (command.expiration == 0) {
      command.expiration = uint88(block.timestamp + DEFAULT_VM_EXPIRATION);
    }
    if (command.ethereumAddress != address(0)) {
      // Needed to validate thisBcAddress
      command.expiration = 0;
    }

    //* Implementation
    // Existence check
    if (_vmIds[command.didHash].contains(command.id)) revert VmAlreadyExists();
    // Add ID to set and compute position
    bool added = _vmIds[command.didHash].add(command.id);
    assert(added);
    uint8 position = uint8(_vmIds[command.didHash].length());
    idHash = _calculateIdHash(command.didHash, command.id);
    positionHash = _calculatePositionHash(command.didHash, position);

    // Store VM
    VerificationMethod storage vm = _vmByNsAndId[command.didHash][command.id];
    vm.id = command.id;
    vm.type_ = command.type_;
    vm.publicKeyMultibase = command.publicKeyMultibase;
    vm.blockchainAccountId = command.blockchainAccountId;
    vm.ethereumAddress = command.ethereumAddress;
    vm.relationships = command.relationships;
    vm.expiration = command.expiration;

    // Map position hash to ID and DID for validateVm lookup and cleanup
    _vmIdByPositionHash[positionHash] = command.id;
    _didHashByPositionHash[positionHash] = command.didHash;
    _positionHashByDidAndId[command.didHash][command.id] = positionHash;

    // Event
    emit VmCreated(command.didHash, command.id, idHash, positionHash);
    return (idHash, positionHash);
  }

  /**
   * @dev Validates a specific verification method (VM) by setting its expiration timestamp.
   * @param positionHash The hash of the verification method (VM) position.
   * @param expiration The expiration timestamp to set.
   * @param sender The address of the sender.
   * @return id The identifier of the validated verification method (VM).
   */
  function _validateVm(bytes32 positionHash, uint256 expiration, address sender) internal returns (bytes32 id) {
    //* Params validation
    // Optional
    if (expiration == 0) {
      expiration = block.timestamp + DEFAULT_VM_EXPIRATION;
    }
    //* Implementation
    bytes32 vmId = _vmIdByPositionHash[positionHash];
    bytes32 didHash = _didHashByPositionHash[positionHash];
    VerificationMethod storage vm = _vmByNsAndId[didHash][vmId];
    if (vm.id == bytes32(0)) revert VmNotFound();
    if (vm.expiration != 0) revert VmAlreadyValidated(); // This means that the VM is already validated
    if (vm.ethereumAddress != sender) revert InvalidSignature(); // This means that the Tx Signer is not the VM's
      // Ethereum Address or actual signature validation
    vm.expiration = uint88(expiration);
    //Event
    emit VmValidated(vm.id);
    return (vm.id);
  }

  /**
   * @dev Expires a specific verification method (VM) by setting its expiration timestamp to the current block
   * timestamp.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM) to expire.
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
      // Delete VM payload
      delete _vmByNsAndId[didHash][lastId];
      // Delete positionHash mappings stored at creation time
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
   * @dev Retrieves a specific verification method (VM) associated with a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @param position The position of the verification method in the array.
   * @return vm The VerificationMethod struct representing the VM.
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

  /**
   * @dev Retrieves the length of the verification methods (VMs) associated with a given DID hash.
   * @param didHash The hash of the decentralized identifier (DID).
   * @return The length of the VMs array.
   */
  function _getVmListLength(bytes32 didHash) internal view returns (uint8) {
    return uint8(_vmIds[didHash].length());
  }

  /**
   * @dev Returns the expiration timestamp of a specific verification method (VM) associated with a given DID hash and
   * VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @return exp The expiration timestamp of the VM.
   */
  function _getExpirationVm(bytes32 didHash, bytes32 id) internal view returns (uint256 exp) {
    return _vmByNsAndId[didHash][id].expiration;
  }

  /**
   * @dev Checks if the given sender is authenticated for the specified DID hash and VM ID.
   * @param didHash The hash of the Decentralized Identifier (DID).
   * @param vmId The ID of the Verification Method (VM).
   * @param sender The address of the sender.
   * @return A boolean indicating whether the sender is authenticated or not. That means that the sender's address is in
   * the authentication relationship of the VM.
   */
  function _isAuthenticated(bytes32 didHash, bytes32 vmId, address sender) internal view returns (bool) {
    return _isVmRelationship(didHash, vmId, 0x01, sender);
  }

  /**
   * @dev Checks if the given sender is in the specified relationship for the specified DID hash and VM ID.
   * @param didHash The hash of the Decentralized Identifier (DID).
   * @param id The ID of the Verification Method (VM).
   * @param relationship The relationship to check.
   * @param sender The address of the sender.
   * @return A boolean indicating whether the sender is in the specified relationship or not.
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
    // Get VM
    VerificationMethod memory vm = _vmByNsAndId[didHash][id];
    // Check if the VM exists and is not expired
    // Note: expiration == 0 means never validated (invalid VM)
    if (vm.expiration == 0 || vm.expiration <= block.timestamp) revert VmAlreadyExpired();
    // Check if the sender is in the VM and if the VM relationship is the same as the one provided
    if (sender != address(0)) {
      return (vm.ethereumAddress == sender && (vm.relationships & relationship) == relationship);
    }
    // else
    return (vm.relationships & relationship == relationship);
  }

  // Helpers
  function _calculatePositionHash(bytes32 namespace, uint8 position) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(namespace, position));
  }

  function _calculateIdHash(bytes32 namespace, bytes32 id) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(namespace, id));
  }
}
