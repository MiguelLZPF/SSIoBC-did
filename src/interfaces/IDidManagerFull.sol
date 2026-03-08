// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager } from "@interfaces/IDidManager.sol";
import { DidCreateVmCommand, VerificationMethod } from "@types/VmTypes.sol";

/// @title IDidManagerFull
/// @author Miguel Gomez Carpena
/// @notice Full W3C DID manager variant — extends IDidManager with full VM operations.
interface IDidManagerFull is IDidManager {
  /// @dev Creates a new Verification Method (VM) based on the provided command.
  function createVm(DidCreateVmCommand memory command) external;

  /// @dev Returns the Verification Method (VM) for a given DID and VM ID.
  function getVm(bytes32 methods, bytes32 id, bytes32 vmId, uint8 position)
    external
    view
    returns (VerificationMethod memory vm);

  /// @dev Returns the length of the Verification Method (VM) list for a given DID.
  function getVmListLength(bytes32 methods, bytes32 id) external view returns (uint8);
}
