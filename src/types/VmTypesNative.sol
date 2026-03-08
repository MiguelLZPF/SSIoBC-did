// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

// =========================================================================
// Constants
// =========================================================================

bytes32 constant DEFAULT_VM_ID_NATIVE = bytes32("vm-0");
uint256 constant DEFAULT_VM_EXPIRATION_NATIVE = 365 days;

// Max length for publicKeyMultibase in native VMs (same as full variant)
uint256 constant MAX_PUBLIC_KEY_MULTIBASE_LENGTH_NATIVE = 1500;

// =========================================================================
// Structs
// =========================================================================

/**
 * @dev Native Verification Method struct optimized for Ethereum-native DIDs.
 * Stores exactly 1 slot (32 bytes) per VM.
 * W3C fields (type_, publicKeyMultibase, blockchainAccountId) are derived at resolution time.
 */
struct VerificationMethod {
  address ethereumAddress; // 20 bytes
  bytes1 relationships; // 1 byte
  uint88 expiration; // 11 bytes = 32 bytes total = 1 slot
}

/**
 * @dev Command struct for creating a native Verification Method (storage-level).
 * Simplified: no type_, blockchainAccountId, or expiration fields.
 * publicKeyMultibase is REQUIRED when keyAgreement (0x04) is set, and FORBIDDEN otherwise.
 */
struct CreateVmCommand {
  bytes32 didHash; // The hash of the decentralized identifier (DID)
  bytes32 id; // The identifier of the verification method (VM)
  address ethereumAddress; // MANDATORY - the Ethereum address for this VM
  bytes1 relationships; // The relationships associated with the VM
  bytes publicKeyMultibase; // Required IFF keyAgreement (0x04) is set; pre-encoded multibase (must start with 'z')
}

/**
 * @dev Command struct for creating a native Verification Method via DidManagerNative (external-facing).
 * Simplified: only 8 fields (vs 11 in the full variant).
 * No type_, blockchainAccountId, or expiration.
 * publicKeyMultibase is REQUIRED when keyAgreement (0x04) is set, and FORBIDDEN otherwise.
 */
struct DidCreateVmCommandNative {
  bytes32 methods; // The DID methods
  bytes32 senderId; // The ID of the sender
  bytes32 senderVmId; // The ID of the sender's VM
  bytes32 targetId; // The ID of the target DID
  bytes32 vmId; // The ID of the verification method
  address ethereumAddress; // MANDATORY - the Ethereum address
  bytes1 relationships; // The relationships of the VM
  bytes publicKeyMultibase; // Required IFF keyAgreement (0x04) is set; pre-encoded multibase (must start with 'z')
}
