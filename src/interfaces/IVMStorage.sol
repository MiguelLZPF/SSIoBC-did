// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager } from "./IDidManager.sol";
// Verification Method Relationships
// None                 => 00000000 => 0x00 => 0
// Authentication       => 00000001 => 0x01 => 1
// AssertionMethod      => 00000010 => 0x02 => 2
// KeyAgreement         => 00000100 => 0x04 => 4
// CapabilityInvocation => 00001000 => 0x08 => 8
// CapabilityDelegation => 00010000 => 0x10 => 16

struct VerificationMethod {
  bytes32 id;
  bytes32[2] type_;
  bytes32[16] publicKey;
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3 // External blockchain account ID
  address thisBCAddress; // An address (account ID) of the blockchain where the VM is stored
  bytes1 relationships; // Relationships XX00000
  uint expiration;
}

interface IVMStorage {}
