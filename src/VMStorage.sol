// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { HashBasedList } from "@lib/hash-based-list/src/HashBasedList.sol";

// Verification Method Relationships    binary  => hex  => dec
// None                             => 00000000 => 0x00 => 0
// Authentication                   => 00000001 => 0x01 => 1
// AssertionMethod                  => 00000010 => 0x02 => 2
// KeyAgreement                     => 00000100 => 0x04 => 4
// CapabilityInvocation             => 00001000 => 0x08 => 8
// CapabilityDelegation             => 00010000 => 0x10 => 16
// All                              => 00011111 => 0x1F => 31

bytes32 constant VM_ID = bytes32("vm-0");

struct VerificationMethod {
  bytes32 id;
  bytes32[2] type_;
  bytes32[16] publicKey;
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3 // External blockchain account ID
  address thisBCAddress; // An address (account ID) of the blockchain where the VM is stored
  bytes1 relationships; // Relationships XX00000
  uint256 expiration; // The expiration date of the VM
}

struct CreateVmCommand {
  bytes32 didHash; // The hash of the decentralized identifier (DID)
  bytes32 id; // The identifier of the verification method (VM)
  bytes32[2] type_; // The type of the verification method (VM)
  bytes32[16] publicKey; // The public key associated with the verification method (VM)
  bytes32[5] blockchainAccountId; // The blockchain account ID associated with the verification method (VM)
  address thisBCAddress; // The address of the blockchain associated with the verification method (VM)
  bytes1 relationships; // The relationships associated with the verification method (VM)
  uint expiration; // The expiration timestamp of the verification method (VM)
}

abstract contract VMStorage is HashBasedList {
  //* Events
  /**
   * @dev Emitted when a new Verification Method (VM) is created for a DID.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the VM.
   * @param idHash The unique identifier hash of the VM.
   * @param positionHash The hash of the position of the VM.
   */
  event VmCreated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bytes32 indexed idHash,
    bytes32 positionHash
  );

  /**
   * @dev Emitted when a VM is validated.
   * @param id The unique identifier of the VM.
   */
  event VmValidated(bytes32 indexed id);

  /**
   * @dev Emitted when the expiration status of a VM is updated.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the VM.
   * @param expired The new expiration status of the VM.
   * @param expiration The new expiration timestamp of the VM.
   */
  event VmExpirationUpdated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bool indexed expired,
    uint256 expiration
  );
  //* Storage
  bytes32[2] private VM_TYPE = [bytes32("EcdsaSecp256k1VerificationKey20"), bytes32("19")];
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private _vm;

  /**
   * @dev Creates a new verification method.
   */
  function _createVM(
    CreateVmCommand memory command
  ) internal returns (bytes32 idHash, bytes32 positionHash) {
    //* Params validation
    // Required
    require(command.didHash != bytes32(0), "DID hash cannot be 0");
    require(
      command.publicKey[0] != bytes32(0) ||
        command.blockchainAccountId[0] != bytes32(0) ||
        command.thisBCAddress != address(0),
      "4th or 5th or 6th param required"
    );
    // Optional
    if (command.id == bytes32(0)) {
      command.id = VM_ID; // "vm-0"
    }
    if (command.type_[0] == bytes32(0)) {
      command.type_ = [VM_TYPE[0], VM_TYPE[1]]; // "EcdsaSecp256k1VerificationKey20", "19"
    }
    if (command.expiration == 0) {
      command.expiration = block.timestamp + 365 days;
    }
    if (command.thisBCAddress != address(0)) {
      // Needed to validate thisBCAddress
      command.expiration = 0;
    }
    //* Implementation
    uint8 position;
    (, , position) = _calculateHashes(command.didHash, command.id);
    require(position == 0, "VM already exists");
    // Add VM to HBL
    (idHash, position) = _addHbl(command.didHash, command.id);
    positionHash = _calculatePositionHash(command.didHash, position);
    VerificationMethod storage vm = _vm[positionHash];
    // Store VM
    vm.id = command.id;
    vm.type_ = command.type_;
    vm.publicKey = command.publicKey;
    vm.blockchainAccountId = command.blockchainAccountId;
    vm.thisBCAddress = command.thisBCAddress;
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
  function _validateVM(
    bytes32 positionHash,
    uint expiration,
    address sender
  ) internal returns (bytes32 id) {
    //* Params validation
    // Optional
    if (expiration == 0) {
      expiration = block.timestamp + 365 days;
    }
    //* Implementation
    VerificationMethod storage vm = _vm[positionHash];
    require(vm.id != bytes32(0), "VM not found");
    require(vm.expiration == 0, "VM already validated");
    require(vm.thisBCAddress == sender, "Cannot validate VM. Invalid Sign"); //! This is the signature validation of the VM
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
  function _expireVM(bytes32 didHash, bytes32 id) internal {
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    VerificationMethod storage vm = _vm[positionHash];
    require(vm.id != bytes32(0), "VM not found");
    vm.expiration = block.timestamp;
    emit VmExpirationUpdated(didHash, id, vm.expiration <= block.timestamp, vm.expiration);
  }

  /**
   * @dev Retrieves a specific verification method (VM) associated with a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @param position The position of the verification method in the array.
   * @return vm The VerificationMethod struct representing the VM.
   */
  function _getVM(
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
  function _getExpirationVM(bytes32 didHash, bytes32 id) internal view returns (uint256 exp) {
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
    require(id != bytes32(0), "VM ID cannot be 0");
    require(relationship != bytes1(0), "Relationship cannot be 0");
    require(relationship <= bytes1(0x1F), "Relationship out of range");
    require(sender != address(0), "Sender cannot be 0");
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    // Get VM
    VerificationMethod memory vm = _vm[positionHash];
    // Check if the VM exists and is not expired
    require(vm.expiration > block.timestamp, "VM expired");
    // Check if the sender is in the VM and if the VM relationship is the same as the one provided
    if (sender != address(0)) {
      return (vm.thisBCAddress == sender && vm.relationships & relationship == relationship);
    }
    // else
    return (vm.relationships & relationship == relationship);
  }
}
