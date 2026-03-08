// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

// * How Verification Method Relationships are represented in the Storage
// Verification Method Relationships    binary  => hex  => dec
// None                             => 00000000 => 0x00 => 0
// Authentication                   => 00000001 => 0x01 => 1
// AssertionMethod                  => 00000010 => 0x02 => 2
// KeyAgreement                     => 00000100 => 0x04 => 4
// CapabilityInvocation             => 00001000 => 0x08 => 8
// CapabilityDelegation             => 00010000 => 0x10 => 16
// All                              => 00011111 => 0x1F => 31

// =========================================================================
// Constants
// =========================================================================

bytes32 constant DEFAULT_VM_ID = bytes32("vm-0");
uint256 constant DEFAULT_VM_EXPIRATION = 365 days;

// Default VM type constants (compile-time, zero storage cost)
bytes32 constant DEFAULT_VM_TYPE_0 = bytes32("EcdsaSecp256k1VerificationKey20");
bytes32 constant DEFAULT_VM_TYPE_1 = bytes32("19");

// Max lengths for dynamic bytes
// Supports RSA-4096 multibase (~709 chars) with buffer
uint256 constant MAX_PUBLIC_KEY_MULTIBASE_LENGTH = 1500;
// CAIP-10 format: chain_id (max ~40 chars) + ":" + account_address (max 128 chars) ~ 170 chars
uint256 constant MAX_BLOCKCHAIN_ACCOUNT_ID_LENGTH = 200;

// =========================================================================
// Structs
// =========================================================================

/**
 * @dev Verification Method struct optimized for gas efficiency.
 * Uses dynamic bytes for flexible key storage and uint88 for expiration packing.
 * - publicKeyMultibase: Pre-encoded multibase string (e.g., "z6MkhaXg...")
 * - blockchainAccountId: CAIP-10 format string (e.g., "eip155:1:0xabc...")
 */
struct VerificationMethod {
  bytes32 id;
  bytes32[2] type_;
  // "controller" field is automatically set to this DID.id
  bytes publicKeyMultibase; // Pre-encoded multibase string (must start with 'z' for base58btc)
  bytes blockchainAccountId; // CAIP-10 format string (stored as-is)
  address ethereumAddress; // 20 bytes - packed with relationships and expiration
  bytes1 relationships; // 1 byte - Relationships XX00000
  uint88 expiration; // 11 bytes - max ~9.8 million years (packed in same slot)
}

/**
 * @dev Command struct for creating a new Verification Method (storage-level).
 */
struct CreateVmCommand {
  bytes32 didHash; // The hash of the decentralized identifier (DID)
  bytes32 id; // The identifier of the verification method (VM)
  bytes32[2] type_; // The type of the verification method (VM)
  bytes publicKeyMultibase; // Pre-encoded multibase string (e.g., "z6MkhaXg...")
  bytes blockchainAccountId; // CAIP-10 format string
  address ethereumAddress; // The address of the blockchain associated with the verification method (VM)
  bytes1 relationships; // The relationships associated with the verification method (VM)
  uint88 expiration; // The expiration timestamp of the verification method (VM)
}

/**
 * @dev Command struct for creating a Verification Method via DidManager (external-facing).
 * Uses optimized storage with dynamic bytes and packed expiration.
 */
struct DidCreateVmCommand {
  bytes32 methods; // The methods used to create the VM, concatenated each one limited to 10 bytes.
  bytes32 senderId; // The ID of the sender.
  bytes32 senderVmId; // The ID of the sender's VM.
  bytes32 targetId; // The ID of the target.
  bytes32 vmId; // The ID of the verification method.
  bytes32[2] type_; // The type of the VM.
  bytes publicKeyMultibase; // Pre-encoded multibase string (e.g., "z6MkhaXg...")
  bytes blockchainAccountId; // CAIP-10 format string (e.g., "eip155:1:0xabc...")
  address ethereumAddress; // The address of the blockchain where the VM is created.
  bytes1 relationships; // The relationships of the VM.
  uint88 expiration; // The expiration time of the VM (packed, max ~9.8 million years).
}
