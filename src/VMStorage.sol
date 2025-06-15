// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { HashBasedList } from "@lib/hash-based-list/src/HashBasedList.sol";
import { DEFAULT_VM_ID, DEFAULT_VM_EXPIRATION, CreateVmCommand, VerificationMethod, IVMStorage } from "./interfaces/IVMStorage.sol";

abstract contract VMStorage is HashBasedList, IVMStorage {
  //* Constant Variables
  // Empty values
  bytes32[16] internal EMPTY_PUBLIC_KEY = [bytes32(0)];
  bytes32[5] internal EMPTY_BLOCKCHAIN_ACCOUNT_ID = [
    bytes32(0),
    bytes32(0),
    bytes32(0),
    bytes32(0),
    bytes32(0)
  ];
  // Default values
  bytes32[2] private DEFAULT_VM_TYPE = [bytes32("EcdsaSecp256k1VerificationKey20"), bytes32("19")];
  //* Storage
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private _vm;

  /**
   * @dev Creates a new verification method.
   * @param command The command containing the parameters for creating the verification method.
   * @dev command.publicKeyMultibase, command.blockchainAccountId OR command.ethereumAddress are required.
   */
  function _createVm(
    CreateVmCommand memory command
  ) internal returns (bytes32 idHash, bytes32 positionHash) {
    //* Params validation
    // Required
    // require(command.didHash != bytes32(0), "DID hash required"); //! Unreachable code
    if (
      command.publicKeyMultibase[0] == bytes32(0) &&
      command.blockchainAccountId[0] == bytes32(0) &&
      command.ethereumAddress == address(0)
    ) {
      revert PubKeyBlockchainAccountORAddressRequired();
    }
    // Optional
    if (command.id == bytes32(0)) {
      command.id = DEFAULT_VM_ID; // "vm-0"
    }
    if (command.type_[0] == bytes32(0)) {
      command.type_ = [DEFAULT_VM_TYPE[0], DEFAULT_VM_TYPE[1]]; // "EcdsaSecp256k1VerificationKey20", "19"
    }
    if (command.expiration == 0) {
      command.expiration = block.timestamp + DEFAULT_VM_EXPIRATION;
    }
    if (command.ethereumAddress != address(0)) {
      // Needed to validate thisBcAddress
      command.expiration = 0;
    }
    //* Implementation
    uint8 position;
    (, , position) = _calculateHashes(command.didHash, command.id);
    if (position != 0) revert VmAlreadyExists();
    // Add VM to HBL
    (idHash, position) = _addHbl(command.didHash, command.id);
    positionHash = _calculatePositionHash(command.didHash, position);
    VerificationMethod storage vm = _vm[positionHash];
    // Store VM
    vm.id = command.id;
    vm.type_ = command.type_;
    vm.publicKeyMultibase = command.publicKeyMultibase;
    vm.blockchainAccountId = command.blockchainAccountId;
    vm.ethereumAddress = command.ethereumAddress;
    vm.relationships = command.relationships;
    vm.expiration = command.expiration;
    //Event
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
  function _validateVm(
    bytes32 positionHash,
    uint expiration,
    address sender
  ) internal returns (bytes32 id) {
    //* Params validation
    // Optional
    if (expiration == 0) {
      expiration = block.timestamp + DEFAULT_VM_EXPIRATION;
    }
    //* Implementation
    VerificationMethod storage vm = _vm[positionHash];
    if (vm.id == bytes32(0)) revert VmNotFound();
    if (vm.expiration != 0) revert VmAlreadyValidated(); // This means that the VM is already validated
    if (vm.ethereumAddress != sender) revert InvalidSignature(); // This means that the Tx Signer is not the VM's Ethereum Address or actual signature validation
    vm.expiration = expiration;
    //Event
    emit VmValidated(vm.id);
    return (vm.id);
  }

  /**
   * @dev Expires a specific verification method (VM) by setting its expiration timestamp to the current block timestamp.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM) to expire.
   */
  function _expireVm(bytes32 didHash, bytes32 id) internal {
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    VerificationMethod storage vm = _vm[positionHash];
    if (vm.expiration <= block.timestamp) revert VmAlreadyExpired();
    vm.expiration = block.timestamp;
    emit VmExpirationUpdated(didHash, id, true, vm.expiration);
  }

  function _removeAllVms(bytes32 didHash) internal {
    for (uint8 i = 1; i <= _getHblLength(didHash); i++) {
      bytes32 positionHash = _calculatePositionHash(didHash, i);
      // Set vmId --> position to 0
      _initHblPosition(didHash, _vm[positionHash].id);
      // Empty VM
      delete _vm[positionHash];
    }
    // Set HBL length to 0
    _initHblLength(didHash);
  }

  /**
   * @dev Retrieves a specific verification method (VM) associated with a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @param position The position of the verification method in the array.
   * @return vm The VerificationMethod struct representing the VM.
   */
  function _getVm(
    bytes32 didHash,
    bytes32 id,
    uint8 position
  ) internal view returns (VerificationMethod memory vm) {
    if (id == bytes32(0)) {
      return _vm[_calculatePositionHash(didHash, position)];
    }
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    return _vm[positionHash];
  }

  /**
   * @dev Retrieves the length of the verification methods (VMs) associated with a given DID hash.
   * @param didHash The hash of the decentralized identifier (DID).
   * @return The length of the VMs array.
   */
  function _getVmListLength(bytes32 didHash) internal view returns (uint8) {
    return _getHblLength(didHash);
  }

  /**
   * @dev Returns the expiration timestamp of a specific verification method (VM) associated with a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @return exp The expiration timestamp of the VM.
   */
  function _getExpirationVm(bytes32 didHash, bytes32 id) internal view returns (uint256 exp) {
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    return _vm[positionHash].expiration;
  }

  /**
   * @dev Checks if the given sender is authenticated for the specified DID hash and VM ID.
   * @param didHash The hash of the Decentralized Identifier (DID).
   * @param vmId The ID of the Verification Method (VM).
   * @param sender The address of the sender.
   * @return A boolean indicating whether the sender is authenticated or not. That means that the sender's address is in the authentication relationship of the VM.
   */
  function _isAuthenticated(
    bytes32 didHash,
    bytes32 vmId,
    address sender
  ) internal view returns (bool) {
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
  function _isVmRelationship(
    bytes32 didHash,
    bytes32 id,
    bytes1 relationship,
    address sender
  ) internal view returns (bool) {
    if (id == bytes32(0) || relationship == bytes1(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
    if (relationship > bytes1(0x1F)) revert VmRelationshipOutOfRange();
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    // Get VM
    VerificationMethod memory vm = _vm[positionHash];
    // Check if the VM exists and is not expired
    if (vm.expiration <= block.timestamp) revert VmAlreadyExpired();
    // Check if the sender is in the VM and if the VM relationship is the same as the one provided
    if (sender != address(0)) {
      return (vm.ethereumAddress == sender && (vm.relationships & relationship) == relationship);
    }
    // else
    return (vm.relationships & relationship == relationship);
  }
}
