// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Vm } from "forge-std/Vm.sol";
import { IDidManagerNative, CreateVmCommand } from "@src/interfaces/IDidManagerNative.sol";
import { DEFAULT_DID_METHODS } from "@src/DidManagerBase.sol";
import { DEFAULT_VM_ID_NATIVE, VerificationMethod } from "@src/interfaces/IVMStorageNative.sol";
import { Fixtures } from "./Fixtures.sol";

/**
 * @title DidTestHelpersNative
 * @notice Test helper functions for native DID operations
 * @dev Provides structured helper functions for common native DID operations in tests
 */
library DidTestHelpersNative {
  // =========================================================================
  // Structs for Test Results
  // =========================================================================

  struct DidInfo {
    bytes32 methods;
    bytes32 id;
    bytes32 idHash;
  }

  struct CreateDidResult {
    DidInfo didInfo;
    bytes32 vmCreatedDidIdHash;
    bytes32 vmCreatedId;
    bytes32 vmValidatedId;
    bytes32 didCreatedId;
    bytes32 didCreatedIdHash;
  }

  struct CreateVmResult {
    bytes32 vmCreatedDidIdHash;
    bytes32 vmCreatedId;
    bytes32 vmCreatedIdHash;
    bytes32 vmCreatedPositionHash;
  }

  // =========================================================================
  // DID Creation Helpers
  // =========================================================================

  /**
   * @notice Creates a DID with default parameters
   */
  function createDefaultDid(Vm vm, IDidManagerNative didManager) internal returns (CreateDidResult memory result) {
    return createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0));
  }

  /**
   * @notice Creates a DID with custom parameters
   */
  function createDid(Vm vm, IDidManagerNative didManager, bytes32 methods, bytes32 random, bytes32 vmId)
    internal
    returns (CreateDidResult memory result)
  {
    vm.recordLogs();
    didManager.createDid(methods, random, vmId);
    Vm.Log[] memory entries = vm.getRecordedLogs();

    // VmCreated event (index 0)
    result.vmCreatedDidIdHash = entries[0].topics[1];
    result.vmCreatedId = entries[0].topics[2];

    // VmValidated event (index 1)
    result.vmValidatedId = entries[1].topics[1];

    // DidCreated event (index 2)
    result.didCreatedId = entries[2].topics[1];
    result.didCreatedIdHash = entries[2].topics[2];

    // Build DID info
    result.didInfo = DidInfo({
      methods: methods != Fixtures.EMPTY_DID_METHODS ? methods : DEFAULT_DID_METHODS,
      id: result.didCreatedId,
      idHash: result.didCreatedIdHash
    });
  }

  // =========================================================================
  // VM Creation Helpers
  // =========================================================================

  /**
   * @notice Creates a verification method with default parameters for native variant
   */
  function createDefaultVm(Vm vm, IDidManagerNative didManager, DidInfo memory didInfo, bytes32 vmId)
    internal
    returns (CreateVmResult memory result)
  {
    CreateVmCommand memory command = CreateVmCommand({
      methods: didInfo.methods,
      senderId: didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didInfo.id,
      vmId: vmId,
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
      publicKeyMultibase: "" // No keyAgreement on default VM
    });

    CreateVmResult memory vmResult = createVm(vm, didManager, command);

    // Validate the VM to make it usable
    if (command.ethereumAddress != address(0)) {
      vm.startPrank(command.ethereumAddress);
      didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
      vm.stopPrank();
    }

    return vmResult;
  }

  /**
   * @notice Creates a verification method with custom parameters
   */
  function createVm(Vm vm, IDidManagerNative didManager, CreateVmCommand memory command)
    internal
    returns (CreateVmResult memory result)
  {
    vm.recordLogs();
    didManager.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();

    // VmCreated event
    result.vmCreatedDidIdHash = entries[0].topics[1];
    result.vmCreatedId = entries[0].topics[2];
    result.vmCreatedIdHash = entries[0].topics[3];
    result.vmCreatedPositionHash = bytes32(entries[0].data);
  }

  // =========================================================================
  // Assertion Helpers
  // =========================================================================

  /**
   * @notice Asserts that a native VM is empty (default state)
   */
  function assertEmptyVm(VerificationMethod memory vm) internal pure {
    assert(vm.ethereumAddress == address(0));
    assert(vm.relationships == bytes1(0));
    assert(vm.expiration == 0);
  }

  // =========================================================================
  // Time Manipulation Helpers
  // =========================================================================

  function warpToFuture(Vm vm, uint256 additionalSeconds) internal {
    vm.warp(block.timestamp + additionalSeconds);
  }

  function warpTo(Vm vm, uint256 timestamp) internal {
    vm.warp(timestamp);
  }
}
