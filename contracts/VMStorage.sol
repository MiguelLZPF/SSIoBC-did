// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IVMStorage} from "./interfaces/IVMStorage.sol";
import {IDidManager} from "./interfaces/IDidManager.sol";
import {Truster} from "decentralized-code-trust/contracts/Truster.sol";

struct VerificationMethod {
  bytes32 id;
  bytes32 type_;
  bytes32 publicKey;
  bytes32 blockchainAccountId; // TODO: change to support all blockchain account ids
}

contract VMStorage is IVMStorage, Truster {
  // hash(DIDHash, position) --> VerificationMethod Details
  mapping(bytes32 => VerificationMethod) private vm;
  // hash(DIDHash, VM ID) --> position
  mapping(bytes32 => uint8) private vmById;
  // DIDHash --> VM length
  mapping(bytes32 => uint8) private vmLength;

  constructor(IDidManager didManager) {
    _codeTrust.trustCodeAt(address(didManager), 1);
  }

  function addVM(
    bytes32 didHash,
    bytes32 id,
    bytes32 type_,
    bytes32 publicKey,
    bytes32 blockchainAccountId
  ) external {
    vm[keccak256(abi.encodePacked(didHash, vmLength[didHash]))] = VerificationMethod(
      id,
      type_,
      publicKey,
      blockchainAccountId
    );
    vmById[keccak256(abi.encodePacked(didHash, id))] = vmLength[didHash];
    vmLength[didHash]++;
  }
}
