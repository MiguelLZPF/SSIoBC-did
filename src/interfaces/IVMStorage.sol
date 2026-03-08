// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

// Re-export types from VmTypes.sol — allows consumers to import types alongside the interface
// (e.g., `import { IVMStorage, CreateVmCommand } from "@interfaces/IVMStorage.sol"`)
// Canonical source: @types/VmTypes.sol
import {
  DEFAULT_VM_ID,
  DEFAULT_VM_EXPIRATION,
  DEFAULT_VM_TYPE_0,
  DEFAULT_VM_TYPE_1,
  MAX_PUBLIC_KEY_MULTIBASE_LENGTH,
  MAX_BLOCKCHAIN_ACCOUNT_ID_LENGTH,
  CreateVmCommand,
  VerificationMethod
} from "@types/VmTypes.sol";

/// @title IVMStorage
/// @author Miguel Gomez Carpena
/// @notice Interface for multi-type VM storage
interface IVMStorage {
  //* Events
  /**
   * @dev Emitted when a new Verification Method (VM) is created for a DID.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the VM.
   * @param idHash The unique identifier hash of the VM.
   * @param positionHash The hash of the position of the VM.
   */
  event VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed idHash, bytes32 positionHash);

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
  event VmExpirationUpdated(bytes32 indexed didIdHash, bytes32 indexed id, bool indexed expired, uint256 expiration);

  // * Errors
  // MissingRequiredParameter: declared in DidTypes.sol (single source of truth)

  error PubKeyBlockchainAccountORAddressRequired();

  error VmAlreadyExists();

  error VmNotFound();

  error VmAlreadyValidated();

  error VmAlreadyExpired();

  // VmRelationshipOutOfRange: declared in DidTypes.sol (single source of truth)

  error InvalidSignature();

  error PublicKeyTooLarge();

  error BlockchainAccountIdTooLarge();

  error InvalidMultibasePrefix();

  error TooManyVerificationMethods();
}
