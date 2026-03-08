// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

// Re-export types from VmTypesNative.sol — allows consumers to import types alongside the interface
// (e.g., `import { IVMStorageNative, CreateVmCommand } from "@interfaces/IVMStorageNative.sol"`)
// Canonical source: @types/VmTypesNative.sol
import {
  DEFAULT_VM_ID_NATIVE,
  DEFAULT_VM_EXPIRATION_NATIVE,
  MAX_PUBLIC_KEY_MULTIBASE_LENGTH_NATIVE,
  CreateVmCommand,
  VerificationMethod
} from "@types/VmTypesNative.sol";

/// @title IVMStorageNative
/// @author Miguel Gomez Carpena
/// @notice Interface for native VM storage
interface IVMStorageNative {
  //* Events
  event VmCreated(bytes32 indexed didIdHash, bytes32 indexed id, bytes32 indexed idHash, bytes32 positionHash);
  event VmValidated(bytes32 indexed id);
  event VmExpirationUpdated(bytes32 indexed didIdHash, bytes32 indexed id, bool indexed expired, uint256 expiration);

  // * Errors
  // MissingRequiredParameter: declared in DidTypes.sol (single source of truth)
  error EthereumAddressRequired();
  error VmAlreadyExists();
  error VmNotFound();
  error VmAlreadyValidated();
  error VmAlreadyExpired();
  // VmRelationshipOutOfRange: declared in DidTypes.sol (single source of truth)
  error InvalidSignature();

  error TooManyVerificationMethods();

  error PublicKeyMultibaseRequiredForKeyAgreement();
  error PublicKeyMultibaseNotAllowedWithoutKeyAgreement();
  error InvalidMultibasePrefix();
  error PublicKeyTooLarge();
}
