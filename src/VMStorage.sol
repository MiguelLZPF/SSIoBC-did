// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

// Verification Method Relationships    binary  => hex  => dec
// None                             => 00000000 => 0x00 => 0
// Authentication                   => 00000001 => 0x01 => 1
// AssertionMethod                  => 00000010 => 0x02 => 2
// KeyAgreement                     => 00000100 => 0x04 => 4
// CapabilityInvocation             => 00001000 => 0x08 => 8
// CapabilityDelegation             => 00010000 => 0x10 => 16
// All                              => 00011111 => 0x1F => 31

struct VerificationMethod {
  bytes32 id;
  bytes32[2] type_;
  bytes32[16] publicKey;
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3 // External blockchain account ID
  address thisBCAddress; // An address (account ID) of the blockchain where the VM is stored
  bytes1 relationships; // Relationships XX00000
  uint256 expiration; // The expiration date of the VM
}

abstract contract VMStorage {
  //* Events
  /**
   * @dev Emitted when a new Verification Method (VM) is created for a DID.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the VM.
   * @param vmIdHash The unique identifier hash of the VM.
   * @param positionHash The hash of the position of the VM.
   */
  event VmCreated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bytes32 indexed vmIdHash,
    bytes32 positionHash
  );

  /**
   * @dev Emitted when a VM is validated.
   * @param id The unique identifier of the VM.
   */
  event VmValidated(bytes32 indexed id);
  //* Storage
  bytes32 private constant VM_ID = bytes32("vm-0");
  bytes32 private constant VM_TYPE_0 = bytes32("EcdsaSecp256k1VerificationKey20");
  bytes32 private constant VM_TYPE_1 = bytes32("19");
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private _vm;
  // hash(DIDHash, VM ID) --> position
  mapping(bytes32 => uint8) private _vmPositionById;
  // DIDHash --> VM length
  mapping(bytes32 => uint8) private _vmLength;

  /**
   * @dev Creates a new Verification Method (VM) and stores it in the contract.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @param type_ The type of the verification method (VM).
   * @param publicKey The public key associated with the verification method (VM).
   * @param blockchainAccountId The blockchain account ID associated with the verification method (VM).
   * @param thisBCAddress The address of the blockchain associated with the verification method (VM).
   * @param relationships The relationships associated with the verification method (VM).
   * @param expiration The expiration timestamp of the verification method (VM).
   * @return vmIdHash The hash of the verification method (VM) ID.
   * @return positionHash The hash of the verification method (VM) position.
   */
  function _createVM(
    bytes32 didHash,
    bytes32 id,
    bytes32[2] memory type_,
    bytes32[16] memory publicKey,
    bytes32[5] memory blockchainAccountId,
    address thisBCAddress,
    bytes1 relationships,
    uint expiration
  ) internal returns (bytes32 vmIdHash, bytes32 positionHash) {
    //* Params validation
    // Required
    require(didHash != bytes32(0), "1st param required"); // "DID hash cannot be 0"
    require(
      publicKey[0] != bytes32(0) ||
        blockchainAccountId[0] != bytes32(0) ||
        thisBCAddress != address(0),
      "4th or 5th or 6th param required" // "PublicKey or blockchainAccountId or thisBCAddress must be set"
    );
    // Optional
    if (id == bytes32(0)) {
      id = VM_ID; // "vm-0"
    }
    if (type_[0] == bytes32(0)) {
      type_ = [VM_TYPE_0, VM_TYPE_1]; // "EcdsaSecp256k1VerificationKey20", "19"
    }
    if (expiration == 0) {
      expiration = block.timestamp + 365 days;
    }
    if (thisBCAddress != address(0)) {
      // Need to validate thisBCAddress
      expiration = 0;
    }
    //* Implementation
    // vmIdHash = keccak256(abi.encodePacked(didHash, id));
    // positionHash = keccak256(abi.encodePacked(didHash, _vmLength[didHash]));
    (vmIdHash, positionHash) = _calculateHashes(didHash, id);
    VerificationMethod storage vm = _vm[positionHash];
    require(vm.id == bytes32(0), "VM already exists");
    // Store VM
    vm.id = id;
    vm.type_ = type_;
    vm.publicKey = publicKey;
    vm.blockchainAccountId = blockchainAccountId;
    vm.thisBCAddress = thisBCAddress;
    vm.relationships = relationships;
    vm.expiration = expiration;
    // Mappings
    _vmPositionById[vmIdHash] = _vmLength[didHash];
    _vmLength[didHash]++;
    //Event
    emit VmCreated(didHash, id, vmIdHash, positionHash);
    return (vmIdHash, positionHash);
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
    require(vm.thisBCAddress == sender, "Cannot validate VM"); // This is the signature validation of the VM
    vm.expiration = expiration;
    //Event
    emit VmValidated(vm.id);
    return (vm.id);
  }

  /**
   * @dev Retrieves a specific verification method (VM) associated with a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param vmId The identifier of the verification method (VM).
   * @return vm The VerificationMethod struct representing the VM.
   */
  function _getVM(
    bytes32 didHash,
    bytes32 vmId
  ) internal view returns (VerificationMethod memory vm) {
    (, bytes32 positionHash) = _calculateHashes(didHash, vmId);
    return _vm[positionHash];
  }

  /**
   * @dev Retrieves the length of the verification methods (VMs) associated with a given DID hash.
   * @param didHash The hash of the decentralized identifier (DID).
   * @return The length of the VMs array.
   */
  function _getVmListLength(bytes32 didHash) internal view returns (uint8) {
    return _vmLength[didHash];
  }

  /**
   * @dev Returns the expiration timestamp of a specific verification method (VM) associated with a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param vmId The identifier of the verification method (VM).
   * @return exp The expiration timestamp of the VM.
   */
  function _getExpirationVM(bytes32 didHash, bytes32 vmId) internal view returns (uint256 exp) {
    (, bytes32 positionHash) = _calculateHashes(didHash, vmId);
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
   * @param vmId The ID of the Verification Method (VM).
   * @param relationship The relationship to check.
   * @param sender The address of the sender.
   * @return A boolean indicating whether the sender is in the specified relationship or not.
   */
  function _isVmRelationship(
    bytes32 didHash,
    bytes32 vmId,
    bytes1 relationship,
    address sender
  ) internal view returns (bool) {
    require(vmId != bytes32(0), "VM ID cannot be 0");
    require(relationship != bytes1(0), "Relationship cannot be 0");
    require(relationship <= bytes1(0x1F), "Invalid relationship");
    require(sender != address(0), "Invalid sender");
    (, bytes32 positionHash) = _calculateHashes(didHash, vmId);
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

  /**
   * @dev Calculates the hashes for a given DID hash and VM ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The identifier of the verification method (VM).
   * @return vmIdHash The hash of the verification method (VM) ID.
   * @return positionHash The hash of the verification method (VM) position.
   */
  function _calculateHashes(
    bytes32 didHash,
    bytes32 id
  ) internal view returns (bytes32 vmIdHash, bytes32 positionHash) {
    vmIdHash = keccak256(abi.encodePacked(didHash, id));
    uint position = _vmPositionById[vmIdHash];
    positionHash = keccak256(abi.encodePacked(didHash, position));
    return (vmIdHash, positionHash);
  }
}
