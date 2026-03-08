// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { DidCreateVmCommandNative, CreateVmCommand, VerificationMethod } from "@types/VmTypesNative.sol";
import { DEFAULT_DID_METHODS, MissingRequiredParameter, DidAlreadyExists } from "@types/DidTypes.sol";
import { VMStorageNative } from "@storage/VMStorageNative.sol";
import { DidAggregate } from "@src/DidAggregate.sol";
import { HashUtils } from "@src/HashUtils.sol";

/// @title DidManagerNative
/// @author Miguel Gomez Carpena
/// @dev Ethereum-native DID manager with 1-slot VM storage.
/// Thin wrapper: only variant-specific functions (createDid, createVm, isAuthorized, getVm, extras).
/// All shared logic lives in DidAggregate.
contract DidManagerNative is IDidManagerNative, VMStorageNative, DidAggregate {
  /// @dev Creates a new Ethereum-native DID with a single-slot Verification Method.
  /// Generates a unique ID from keccak256(methods, random, tx.origin, block.prevrandao).
  /// The initial VM is created with authentication relationship and tx.origin as ethereumAddress.
  /// @param methods The DID methods (bytes32 with three 10-byte segments). Uses DEFAULT_DID_METHODS if zero.
  /// @param random A random bytes32 value for unique ID generation. Must be non-zero.
  /// @param vmId The identifier for the initial Verification Method.
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external virtual {
    if (random == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    if (methods == bytes32(0)) {
      methods = DEFAULT_DID_METHODS;
    }
    bytes32 id = keccak256(abi.encodePacked(methods, random, tx.origin, block.prevrandao));
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    if (!_isExpired(idHash)) {
      revert DidAlreadyExists();
    }
    _removeAllVms(idHash);
    _removeAllServices(idHash);
    (, bytes32 positionHash) = _createVm(
      CreateVmCommand({
        didHash: idHash,
        id: vmId,
        ethereumAddress: tx.origin,
        relationships: bytes1(0x01), // Authentication
        publicKeyMultibase: "" // No keyAgreement on default VM
      })
    );
    _validateVm(positionHash, 0, tx.origin);
    updateExpiration({ idHash: idHash, forceExpire: false });
    emit DidCreated(id, idHash);
  }

  /// @dev Creates a new native Verification Method (VM).
  function createVm(DidCreateVmCommandNative memory command) external {
    _validateTripleParams(command.methods, command.senderId, command.targetId);
    if (command.relationships == bytes1(0)) revert MissingRequiredParameter();
    (, bytes32 targetIdHash) = _validateSenderAndTarget({
      methods: command.methods, senderId: command.senderId, senderVmId: command.senderVmId, targetId: command.targetId
    });
    _createVm(
      CreateVmCommand({
        didHash: targetIdHash,
        id: command.vmId,
        ethereumAddress: command.ethereumAddress,
        relationships: command.relationships,
        publicKeyMultibase: command.publicKeyMultibase
      })
    );
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  /// @dev Returns the Verification Method (VM) for a given DID.
  function getVm(bytes32 methods, bytes32 id, bytes32 vmId, uint8 position)
    external
    view
    returns (VerificationMethod memory vm)
  {
    return _getVm(HashUtils.calculateIdHash(methods, id), vmId, position);
  }

  /// @dev Returns the length of the VM list for a given DID.
  function getVmListLength(bytes32 methods, bytes32 id) external view returns (uint8) {
    return _getVmListLength(HashUtils.calculateIdHash(methods, id));
  }

  /// @dev Returns the publicKeyMultibase for a native VM.
  function getVmPublicKeyMultibase(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (bytes memory) {
    return _getPublicKeyMultibase(HashUtils.calculateIdHash(methods, id), vmId);
  }

  /// @dev Returns the VM ID at a given position.
  function getVmIdAtPosition(bytes32 methods, bytes32 id, uint8 position) external view returns (bytes32) {
    return _getVmIdAtPosition(HashUtils.calculateIdHash(methods, id), position);
  }
}
