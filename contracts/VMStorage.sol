// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IVMStorage} from "./interfaces/IVMStorage.sol";
import {IDidManager} from "./interfaces/IDidManager.sol";
import {Truster} from "decentralized-code-trust/contracts/Truster.sol";

struct VerificationMethod {
  bytes32 id;
  bytes32 type_;
  bytes32[16] publicKey;
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3
  bool authentication;
  bool assertionMethod;
  bool keyAgreement;
  bool capabilityInvocation;
  bool capabilityDelegation;
}

contract VMStorage is IVMStorage, Truster {
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private _vm;
  // hash(DIDHash, VM ID) --> position
  mapping(bytes32 => uint8) private _vmById;
  // DIDHash --> VM length
  mapping(bytes32 => uint8) private _vmLength;

  constructor(IDidManager didManager) {
    _codeTrust.trustCodeAt(address(didManager), 1);
  }

  function createVM(
    bytes32 didHash,
    bytes32 id,
    bytes32 type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId /* onlyTrusted */
  ) external returns (bytes32) {
    return _createVM(didHash, id, type_, publicKey, blockchainAccountId);
  }

  function _createVM(
    bytes32 didHash,
    bytes32 id,
    bytes32 type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId
  ) internal returns (bytes32) {
    require(didHash != bytes32(0), "1st param required"); // "DID hash cannot be 0"
    require(id != bytes32(0), "2nd param required"); // "VM ID cannot be 0"
    require(
      publicKey[0] != bytes32(0) || blockchainAccountId[0] != bytes32(0),
      "4th or 5th param required" // "PublicKey or blockchainAccountId must be set"
    );
    bytes32 positionHash = keccak256(abi.encodePacked(didHash, _vmLength[didHash]));
    bytes32 vmIdHash = keccak256(abi.encodePacked(didHash, id));
    _vm[positionHash] = VerificationMethod(
      id,
      type_,
      publicKey,
      blockchainAccountId,
      true,
      false,
      false,
      false,
      false
    );
    _vmById[vmIdHash] = _vmLength[didHash];
    _vmLength[didHash]++;
    //Event
    return vmIdHash;
  }
}
