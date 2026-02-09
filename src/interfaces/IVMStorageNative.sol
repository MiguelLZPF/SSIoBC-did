// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

// =========================================================================
// Constants
// =========================================================================

bytes32 constant DEFAULT_VM_ID_NATIVE = bytes32("vm-0");
uint256 constant DEFAULT_VM_EXPIRATION_NATIVE = 365 days;

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
 * @dev Command struct for creating a native Verification Method.
 * Simplified: no type_, publicKeyMultibase, blockchainAccountId, or expiration fields.
 */
struct CreateVmCommand {
  bytes32 didHash; // The hash of the decentralized identifier (DID)
  bytes32 id; // The identifier of the verification method (VM)
  address ethereumAddress; // MANDATORY - the Ethereum address for this VM
  bytes1 relationships; // The relationships associated with the VM
}

interface IVMStorageNative {
  //* Events
  event VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed idHash, bytes32 positionHash);
  event VmValidated(bytes32 indexed id);
  event VmExpirationUpdated(bytes32 indexed didIdHash, bytes32 indexed id, bool indexed expired, uint256 expiration);

  // * Errors
  error MissingRequiredParameter();
  error EthereumAddressRequired();
  error VmAlreadyExists();
  error VmNotFound();
  error VmAlreadyValidated();
  error VmAlreadyExpired();
  error VmRelationshipOutOfRange();
  error InvalidSignature();

  error TooManyVerificationMethods();
}
