// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { VerificationMethod } from "./interfaces/IVMStorage.sol";

abstract contract VMStorage {
  bytes32 private constant VM_ID =
    bytes32(0x766d2d3000000000000000000000000000000000000000000000000000000000); // "vm-0"
  bytes32 private constant VM_TYPE_0 =
    bytes32(0x4563647361536563703235366b31566572696669636174696f6e4b6579323000); // "EcdsaSecp256k1VerificationKey20"
  bytes32 private constant VM_TYPE_1 =
    bytes32(0x3139000000000000000000000000000000000000000000000000000000000000); // "19"
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private _vm;
  // hash(DIDHash, VM ID) --> position
  mapping(bytes32 => uint8) private _vmPositionById;
  // DIDHash --> VM length
  mapping(bytes32 => uint8) private _vmLength;

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
    require(id != bytes32(0), "2nd param required"); // "VM ID cannot be 0"
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
    return (vmIdHash, positionHash);
  }

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
    return (vm.id);
  }

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
