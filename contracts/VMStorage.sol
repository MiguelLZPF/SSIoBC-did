// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IVMStorage, VerificationMethod} from "./interfaces/IVMStorage.sol";
import {IDidManager} from "./interfaces/IDidManager.sol";
import {Truster} from "decentralized-code-trust/contracts/Truster.sol";

contract VMStorage is IVMStorage, Truster {
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private _vm;
  // hash(DIDHash, VM ID) --> position
  mapping(bytes32 => uint8) private _vmPositionById;
  // DIDHash --> VM length
  mapping(bytes32 => uint8) private _vmLength;

  constructor(IDidManager didManager) {
    _codeTrust.trustCodeAt(address(didManager), 1);
  }

  // function createFirstVM(
  //   bytes32 didHash,
  //   bytes32 id,
  //   bytes32 type_,
  //   bytes32[16] calldata publicKey,
  //   bytes32[5] calldata blockchainAccountId /* onlyTrusted */,
  //   uint expiration
  // ) external returns (bytes32 vmIdHash, bytes32 positionHash) {
  //   (vmIdHash, positionHash) = _createVM(didHash, id, type_, publicKey, blockchainAccountId);
  //   _validateVM(positionHash, expiration);
  //   return (vmIdHash, positionHash);
  // }

  function createVM(
    bytes32 didHash,
    bytes32 id,
    bytes32 type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId /* onlyTrusted */
  ) external returns (bytes32 vmIdHash, bytes32 positionHash) {
    return _createVM(didHash, id, type_, publicKey, blockchainAccountId);
  }

  function validateVM(bytes32 positionHash /* onlyTrusted */, uint expiration) external {
    _validateVM(positionHash, expiration);
  }

  function _createVM(
    bytes32 didHash,
    bytes32 id,
    bytes32 type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId
  ) internal returns (bytes32 vmIdHash, bytes32 positionHash) {
    require(didHash != bytes32(0), "1st param required"); // "DID hash cannot be 0"
    require(id != bytes32(0), "2nd param required"); // "VM ID cannot be 0"
    require(
      publicKey[0] != bytes32(0) || blockchainAccountId[0] != bytes32(0),
      "4th or 5th param required" // "PublicKey or blockchainAccountId must be set"
    );
    vmIdHash = keccak256(abi.encodePacked(didHash, id));
    _checkVmIsEmpty(keccak256(abi.encodePacked(didHash, _vmPositionById[vmIdHash])));
    positionHash = keccak256(abi.encodePacked(didHash, _vmLength[didHash]));
    _vm[positionHash] = VerificationMethod(
      id,
      type_,
      publicKey,
      blockchainAccountId,
      true,
      false,
      false,
      false,
      false,
      0
    );
    _vmPositionById[vmIdHash] = _vmLength[didHash];
    _vmLength[didHash]++;
    //Event
    return (vmIdHash, positionHash);
  }

  function _validateVM(bytes32 positionHash, uint expiration) internal {
    VerificationMethod storage vm = _vm[positionHash];
    require(vm.id != bytes32(0), "VM not found");
    require(vm.expiration == 0, "VM already validated");
    vm.expiration = expiration;
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

  function _checkVmIsEmpty(bytes32 positionHash) internal {
    require(_vm[positionHash].id == bytes32(0), "VM already exists");
  }
}
