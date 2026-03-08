// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { DidCreateVmCommand, CreateVmCommand, VerificationMethod } from "@types/VmTypes.sol";
import { DEFAULT_DID_METHODS, MissingRequiredParameter, DidAlreadyExists } from "@types/DidTypes.sol";
import { VMStorage } from "@storage/VMStorage.sol";
import { DidAggregate } from "@src/DidAggregate.sol";
import { HashUtils } from "@src/HashUtils.sol";

/// @title DidManager
/// @author Miguel Gomez Carpena
/// @notice Full W3C DID lifecycle with multi-type VMs.
/// Thin wrapper: only variant-specific functions (createDid, createVm, isAuthorized, getVm, getVmListLength).
/// All shared logic lives in DidAggregate.
contract DidManager is IDidManagerFull, VMStorage, DidAggregate {
  /// @dev Creates a new Decentralized Identifier (DID) with a full W3C Verification Method.
  /// Generates a unique ID from keccak256(methods, random, tx.origin, block.prevrandao).
  /// The initial VM is created with authentication relationship and tx.origin as ethereumAddress.
  /// @param methods The DID methods (bytes32 with three 10-byte segments). Uses DEFAULT_DID_METHODS if zero.
  /// @param random A random bytes32 value for unique ID generation. Must be non-zero.
  /// @param vmId The identifier for the initial Verification Method.
  function createDid(bytes32 methods, bytes32 random, bytes32 vmId) external virtual {
    //* Params validation
    if (random == bytes32(0)) {
      revert MissingRequiredParameter();
    }
    if (methods == bytes32(0)) {
      methods = DEFAULT_DID_METHODS;
    }
    //* Implementation
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
        type_: [bytes32(0), bytes32(0)],
        publicKeyMultibase: "", // Empty - using ethereumAddress for auth
        blockchainAccountId: "", // Empty CAIP-10 string
        ethereumAddress: tx.origin,
        relationships: bytes1(0x01), // 0x01 (Authentication)
        expiration: 1 // Non-zero sentinel: bypasses default-expiration logic in _createVm; _validateVm sets final value
      })
    );
    _validateVm(positionHash, 0, tx.origin);
    updateExpiration({ idHash: idHash, forceExpire: false });
    emit DidCreated(id, idHash);
  }

  /// @dev Creates a new Verification Method (VM) using the full W3C command.
  function createVm(DidCreateVmCommand memory command) external {
    //* Params validation
    _validateTripleParams(command.methods, command.senderId, command.targetId);
    if (command.relationships == bytes1(0)) revert MissingRequiredParameter();
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget({
      methods: command.methods, senderId: command.senderId, senderVmId: command.senderVmId, targetId: command.targetId
    });
    _createVm(
      CreateVmCommand({
        didHash: targetIdHash,
        id: command.vmId,
        type_: command.type_,
        publicKeyMultibase: command.publicKeyMultibase,
        blockchainAccountId: command.blockchainAccountId,
        ethereumAddress: command.ethereumAddress,
        relationships: command.relationships,
        expiration: command.expiration
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
}
