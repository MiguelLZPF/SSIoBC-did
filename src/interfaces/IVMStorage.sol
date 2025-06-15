// SPDX-License-Identifier: UNLICENSED
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

bytes32 constant DEFAULT_VM_ID = bytes32("vm-0");
uint256 constant DEFAULT_VM_EXPIRATION = 365 days;

struct VerificationMethod {
  bytes32 id;
  bytes32[2] type_;
  // "controller" field is automatically set to this DID.id
  bytes32[16] publicKeyMultibase; // The public key associated with the verification method (VM) in multibase format
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3 // External blockchain account ID
  address ethereumAddress; // An address (account ID) of the blockchain where the VM is stored
  bytes1 relationships; // Relationships XX00000
  uint256 expiration; // The expiration date of the VM
}

struct CreateVmCommand {
  bytes32 didHash; // The hash of the decentralized identifier (DID)
  bytes32 id; // The identifier of the verification method (VM)
  bytes32[2] type_; // The type of the verification method (VM)
  bytes32[16] publicKeyMultibase; // The public key associated with the verification method (VM) in multibase format
  bytes32[5] blockchainAccountId; // The blockchain account ID associated with the verification method (VM)
  address ethereumAddress; // The address of the blockchain associated with the verification method (VM)
  bytes1 relationships; // The relationships associated with the verification method (VM)
  uint256 expiration; // The expiration timestamp of the verification method (VM)
}

interface IVMStorage {
  //* Events
  /**
   * @dev Emitted when a new Verification Method (VM) is created for a DID.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the VM.
   * @param idHash The unique identifier hash of the VM.
   * @param positionHash The hash of the position of the VM.
   */
  event VmCreated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bytes32 indexed idHash,
    bytes32 positionHash
  );

  /**
   * @dev Emitted when a VM is validated.
   * @param id The unique identifier of the VM.
   */
  event VmValidated(bytes32 indexed id);

  /**
   * @dev Emitted when the expiration status of a VM is updated.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the VM.
   * @param expired The new expiration status of the VM.
   * @param expiration The new expiration timestamp of the VM.
   */
  event VmExpirationUpdated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bool indexed expired,
    uint256 expiration
  );

  // * Errors
  error MissingRequiredParameter();

  error PubKeyBlockchainAccountORAddressRequired();

  error VmAlreadyExists();

  error VmNotFound();

  error VmAlreadyValidated();

  error VmAlreadyExpired();

  error VmRelationshipOutOfRange();

  error InvalidSignature();
}
