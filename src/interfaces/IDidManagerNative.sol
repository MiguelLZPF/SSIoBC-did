// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager } from "@interfaces/IDidManager.sol";
import { VerificationMethod, DidCreateVmCommandNative } from "@types/VmTypesNative.sol";

/// @title IDidManagerNative
/// @author Miguel Gomez Carpena
/// @dev Interface for managing Ethereum-native DIDs with 1-slot VM storage.
/// Extends IDidManager (Liskov-safe composite) with native-specific VM operations.
interface IDidManagerNative is IDidManager {
  /// @dev Creates a new native Verification Method (VM).
  function createVm(DidCreateVmCommandNative memory command) external;

  /// @dev Returns the Verification Method (VM) for a given DID and VM ID.
  function getVm(bytes32 methods, bytes32 id, bytes32 vmId, uint8 position)
    external
    view
    returns (VerificationMethod memory vm);

  /// @dev Returns the length of the Verification Method (VM) list for a given DID.
  function getVmListLength(bytes32 methods, bytes32 id) external view returns (uint8);

  /// @dev Returns the publicKeyMultibase for a native VM.
  function getVmPublicKeyMultibase(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (bytes memory);

  /// @dev Returns the VM ID at a given position.
  function getVmIdAtPosition(bytes32 methods, bytes32 id, uint8 position) external view returns (bytes32);
}
