// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {ICodeTrust} from "decentralized-code-trust/contracts/interfaces/ICodeTrust.sol";
import {IDidManager} from "./IDidManager.sol";

struct VerificationMethod {
  bytes32 id;
  bytes32[2] type_;
  bytes32[16] publicKey;
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3 // External blockchain account ID
  address thisBCAddress; // An address (account ID) of the blockchain where the VM is stored
  bool authentication;
  bool assertionMethod;
  bool keyAgreement;
  bool capabilityInvocation;
  bool capabilityDelegation;
  uint expiration;
}

interface IVMStorage {}
