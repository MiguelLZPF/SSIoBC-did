// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Vm } from "forge-std/Vm.sol";
import { IDidManager, CreateVmCommand, VerificationMethod } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_DID_METHODS } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";
import { Fixtures } from "./Fixtures.sol";

/**
 * @title DidTestHelpers
 * @notice Test helper functions for DID operations
 * @dev Provides structured helper functions for common DID operations in tests
 */
library DidTestHelpers {
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
   * @param vm The Foundry VM instance
   * @param didManager The DID manager contract
   * @return result The creation result with event data
   */
  function createDefaultDid(Vm vm, IDidManager didManager) internal returns (CreateDidResult memory result) {
    return createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0));
  }

  /**
   * @notice Creates a DID with custom parameters
   * @param vm The Foundry VM instance
   * @param didManager The DID manager contract
   * @param methods The DID methods
   * @param random The random value
   * @param vmId The initial VM ID
   * @return result The creation result with event data
   */
  function createDid(Vm vm, IDidManager didManager, bytes32 methods, bytes32 random, bytes32 vmId)
    internal
    returns (CreateDidResult memory result)
  {
    // Record events
    vm.recordLogs();

    // Create DID
    didManager.createDid(methods, random, vmId);

    // Parse events
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
   * @notice Creates a verification method with default parameters
   * @param vm The Foundry VM instance
   * @param didManager The DID manager contract
   * @param didInfo The DID information
   * @param vmId The VM ID
   * @return result The creation result
   */
  function createDefaultVm(Vm vm, IDidManager didManager, DidInfo memory didInfo, bytes32 vmId)
    internal
    returns (CreateVmResult memory result)
  {
    CreateVmCommand memory command = CreateVmCommand({
      methods: didInfo.methods,
      senderId: didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didInfo.id,
      vmId: vmId,
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });

    CreateVmResult memory vmResult = createVm(vm, didManager, command);

    // Validate the VM to make it usable (VMs with ethereum addresses need validation)
    if (command.ethereumAddress != address(0)) {
      vm.startPrank(command.ethereumAddress);
      didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
      vm.stopPrank();
    }

    return vmResult;
  }

  /**
   * @notice Creates a verification method with custom parameters
   * @param vm The Foundry VM instance
   * @param didManager The DID manager contract
   * @param command The VM creation command
   * @return result The creation result
   */
  function createVm(Vm vm, IDidManager didManager, CreateVmCommand memory command)
    internal
    returns (CreateVmResult memory result)
  {
    // Record events
    vm.recordLogs();

    // Create VM
    didManager.createVm(command);

    // Parse events
    Vm.Log[] memory entries = vm.getRecordedLogs();

    // VmCreated event
    result.vmCreatedDidIdHash = entries[0].topics[1];
    result.vmCreatedId = entries[0].topics[2];
    result.vmCreatedIdHash = entries[0].topics[3];
    result.vmCreatedPositionHash = bytes32(entries[0].data);

    // Note: VM validation should be done separately by tests that need it
  }

  // =========================================================================
  // Assertion Helpers
  // =========================================================================

  /**
   * @notice Asserts that a VM is empty (default state)
   * @param vm The verification method to check
   */
  function assertEmptyVm(VerificationMethod memory vm) internal pure {
    assert(vm.type_[0] == bytes32(0));
    assert(vm.type_[1] == bytes32(0));
    assert(vm.publicKeyMultibase.length == 0);
    assert(vm.blockchainAccountId.length == 0);
    assert(vm.ethereumAddress == address(0));
    assert(vm.relationships == bytes1(0));
    assert(vm.expiration == 0);
  }

  /**
   * @notice Asserts VM properties match expected values
   * @param actualVm The actual verification method
   * @param expectedVmType Expected VM type
   * @param expectedAddress Expected ethereum address
   * @param expectedRelationships Expected relationships
   * @param expectedExpiration Expected expiration (as uint88)
   */
  function assertVm(
    VerificationMethod memory actualVm,
    bytes32[2] memory expectedVmType,
    address expectedAddress,
    bytes1 expectedRelationships,
    uint88 expectedExpiration
  ) internal pure {
    assert(actualVm.type_[0] == expectedVmType[0]);
    assert(actualVm.type_[1] == expectedVmType[1]);
    assert(actualVm.ethereumAddress == expectedAddress);
    assert(actualVm.relationships == expectedRelationships);
    assert(actualVm.expiration == expectedExpiration);
  }

  // =========================================================================
  // Time Manipulation Helpers
  // =========================================================================

  /**
   * @notice Warps to a future timestamp
   * @param vm The Foundry VM instance
   * @param additionalSeconds Seconds to add to current timestamp
   */
  function warpToFuture(Vm vm, uint256 additionalSeconds) internal {
    vm.warp(block.timestamp + additionalSeconds);
  }

  /**
   * @notice Warps to a specific timestamp
   * @param vm The Foundry VM instance
   * @param timestamp Target timestamp
   */
  function warpTo(Vm vm, uint256 timestamp) internal {
    vm.warp(timestamp);
  }
}
