// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

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
  uint expiration;
}

interface IVMStorage {}
