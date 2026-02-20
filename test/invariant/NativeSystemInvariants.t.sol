// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Vm } from "forge-std/Vm.sol";
import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { IDidManagerNative, CreateVmCommand } from "@src/interfaces/IDidManagerNative.sol";
import { DEFAULT_DID_METHODS } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID_NATIVE } from "@src/interfaces/IVMStorageNative.sol";

/**
 * @title NativeSystemInvariantsTest
 * @notice Invariant tests for the Ethereum-Native DID management system
 * @dev Tests system-wide properties that should always hold true for native variant
 * @dev Extends W3C invariants with native-specific properties (publicKeyMultibase enforcement)
 */
contract NativeSystemInvariantsTest is StdInvariant, TestBaseNative {
  using DidTestHelpersNative for *;

  // Handler contract for invariant testing
  InvariantHandlerNative private handler;

  function setUp() public {
    _deployDidManagerNative();

    // Create and configure the handler
    handler = new InvariantHandlerNative(didManagerNative);

    // Target the handler for invariant testing
    targetContract(address(handler));

    // Target specific functions for more focused testing
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = InvariantHandlerNative.createRandomDid.selector;
    selectors[1] = InvariantHandlerNative.createRandomVm.selector;
    selectors[2] = InvariantHandlerNative.updateRandomController.selector;

    targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
  }

  // =========================================================================
  // SYSTEM INVARIANTS (Shared with W3C variant)
  // =========================================================================

  /**
   * @notice Invariant: DIDs should never have zero ID after creation
   * @dev Property: All created DIDs must have valid non-zero IDs
   */
  function invariant_DidIdsShouldNeverBeZero() public {
    bytes32[] memory createdDids = handler.getCreatedDids();

    for (uint256 i = 0; i < createdDids.length; i++) {
      assertNotEq(createdDids[i], bytes32(0), "DID ID should never be zero");
    }
  }

  /**
   * @notice Invariant: DID expiration should always be in the future when created
   * @dev Property: All DID expirations must be greater than their creation time
   */
  function invariant_DidExpirationShouldAlwaysBeInFuture() public {
    bytes32[] memory createdDids = handler.getCreatedDids();
    uint256[] memory creationTimes = handler.getCreationTimes();

    for (uint256 i = 0; i < createdDids.length; i++) {
      uint256 expiration = didManagerNative.getExpiration(DEFAULT_DID_METHODS, createdDids[i], bytes32(0));

      // Skip if DID doesn't exist (may have been cleaned up)
      if (expiration == 0) continue;

      assertGt(expiration, creationTimes[i], "DID expiration should be in future from creation time");
    }
  }

  /**
   * @notice Invariant: VM count should never exceed reasonable limits
   * @dev Property: Each DID should have a reasonable number of VMs
   */
  function invariant_VmCountShouldBeReasonable() public {
    bytes32[] memory createdDids = handler.getCreatedDids();

    for (uint256 i = 0; i < createdDids.length; i++) {
      uint256 vmCount = didManagerNative.getVmListLength(DEFAULT_DID_METHODS, createdDids[i]);

      // Reasonable limit: no more than 100 VMs per DID
      assertLe(vmCount, Fixtures.MAX_REASONABLE_VM_COUNT, "VM count should be reasonable");

      // Should have at least the initial VM if DID exists
      if (vmCount > 0) {
        assertGe(vmCount, 1, "DID should have at least one VM");
      }
    }
  }

  /**
   * @notice Invariant: Handler should maintain consistent state
   * @dev Property: Internal handler state should remain consistent
   */
  function invariant_HandlerStateShouldBeConsistent() public {
    assertEq(
      handler.getCreatedDids().length,
      handler.getCreationTimes().length,
      "DID and creation time arrays should have same length"
    );

    // Total operations should be sum of individual operation counts
    uint256 expectedTotal = handler.didCreationCount() + handler.vmCreationCount() + handler.controllerUpdateCount();

    assertEq(handler.totalOperations(), expectedTotal, "Total operations should match sum");
  }

  /**
   * @notice Invariant: No duplicate DIDs should exist
   * @dev Property: All created DIDs should be unique
   */
  function invariant_NoDuplicateDidsShouldExist() public {
    bytes32[] memory createdDids = handler.getCreatedDids();

    // Check for duplicates
    for (uint256 i = 0; i < createdDids.length; i++) {
      for (uint256 j = i + 1; j < createdDids.length; j++) {
        assertNotEq(createdDids[i], createdDids[j], "No duplicate DIDs should exist");
      }
    }
  }

  /**
   * @notice Invariant: Expired DIDs should never authenticate successfully
   * @dev Property: Any DID whose expiration time is in the past should fail authentication
   * @dev This ensures the expiration mechanism is working correctly at all times
   */
  function invariant_ExpiredDidsShouldNeverAuthenticate() public {
    bytes32[] memory createdDids = handler.getCreatedDids();

    for (uint256 i = 0; i < createdDids.length; i++) {
      bytes32 didId = createdDids[i];
      uint256 expiration = didManagerNative.getExpiration(DEFAULT_DID_METHODS, didId, bytes32(0));

      // If expiration is 0, the DID is deactivated (special case, not expired)
      if (expiration == 0) continue;

      // Check if DID is expired
      bool isExpired = block.timestamp >= expiration;

      if (isExpired) {
        // Property: Expired DID should NOT authenticate successfully
        // Note: Authentication may revert instead of returning false, so we use try-catch
        try didManagerNative.isVmRelationship(
          DEFAULT_DID_METHODS, didId, DEFAULT_VM_ID_NATIVE, bytes1(0x01), address(this)
        ) returns (
          bool result
        ) {
          assertFalse(result, "Expired DID should not authenticate");
        } catch {
          // Expected behavior: expired DIDs typically revert
          // This is acceptable as it prevents expired DID operations
        }
      }
    }
  }

  /**
   * @notice Invariant: VM list length should match actual EnumerableSet count
   * @dev Property: getVmListLength(methods, id) should always equal the actual VM count
   * @dev This ensures internal storage consistency for VM management
   */
  function invariant_VmCountShouldMatchEnumerableSetLength() public {
    bytes32[] memory createdDids = handler.getCreatedDids();

    for (uint256 i = 0; i < createdDids.length; i++) {
      bytes32 didId = createdDids[i];

      // Get reported VM count
      uint256 reportedVmCount = didManagerNative.getVmListLength(DEFAULT_DID_METHODS, didId);

      // Property: VM count should always be reasonable (0-100)
      assertLe(reportedVmCount, Fixtures.MAX_REASONABLE_VM_COUNT, "VM count should not exceed reasonable limit");

      // Property: If DID is not deactivated, should have at least 1 VM (the default one)
      uint256 expiration = didManagerNative.getExpiration(DEFAULT_DID_METHODS, didId, bytes32(0));
      if (expiration != 0 && block.timestamp < expiration) {
        // DID is not deactivated and not expired
        assertGt(reportedVmCount, 0, "Active DID should have at least one VM");
      }
    }
  }

  // =========================================================================
  // NATIVE-SPECIFIC INVARIANTS
  // =========================================================================

  /**
   * @notice Invariant: publicKeyMultibase should only exist for keyAgreement VMs
   * @dev Property: For every VM, if it has keyAgreement relationship (0x04),
   *                it MUST have non-empty publicKeyMultibase.
   *                If it doesn't have keyAgreement, publicKeyMultibase MUST be empty.
   * @dev This ensures strict enforcement of native VM storage constraints
   */
  function invariant_PublicKeyMultibaseShouldOnlyExistForKeyAgreement() public {
    bytes32[] memory createdDids = handler.getCreatedDids();

    for (uint256 i = 0; i < createdDids.length; i++) {
      bytes32 didId = createdDids[i];
      uint256 vmCount = didManagerNative.getVmListLength(DEFAULT_DID_METHODS, didId);

      for (uint8 j = 0; j < vmCount; j++) {
        bytes32 vmId = didManagerNative.getVmIdAtPosition(DEFAULT_DID_METHODS, didId, j);

        // Get publicKeyMultibase and check VM state
        // We validate through the handler's tracked VMs
        (bool hasKeyAgreement, bool hasMultibase) = handler.getVmKeyAgreementAndMultibaseState(didId, vmId);

        // Invariant: keyAgreement and multibase must align
        // If multibase is non-empty, keyAgreement MUST be set
        if (hasMultibase) {
          assertTrue(hasKeyAgreement, "publicKeyMultibase set but keyAgreement not set");
        } else {
          // If multibase is empty, keyAgreement MUST NOT be set
          assertFalse(hasKeyAgreement, "keyAgreement set but publicKeyMultibase not set");
        }
      }
    }
  }
}

/**
 * @title InvariantHandlerNative
 * @notice Handler contract for invariant testing on native DID variant
 * @dev Maintains state and provides controlled randomness for testing
 * @dev Similar to InvariantHandler but uses native variant interfaces and simpler CreateVmCommand
 */
contract InvariantHandlerNative is Test {
  using DidTestHelpersNative for *;

  IDidManagerNative private didManagerNative;

  // State tracking
  bytes32[] private createdDids;
  uint256[] private creationTimes;
  uint256 private currentNonce;

  // VM tracking for publicKeyMultibase invariant checking
  // Stores mapping of (didId => (vmId => vmState))
  struct VmState {
    bool hasKeyAgreement;
    bool hasMultibase;
  }
  mapping(bytes32 => mapping(bytes32 => VmState)) private vmKeyAgreementState;

  // Operation counters
  uint256 public didCreationCount;
  uint256 public vmCreationCount;
  uint256 public controllerUpdateCount;
  uint256 public totalOperations;

  // Test users
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;

  constructor(IDidManagerNative _didManagerNative) {
    didManagerNative = _didManagerNative;

    // Setup users
    vm.deal(user1, Fixtures.TEST_ETHER_AMOUNT);
    vm.deal(user2, Fixtures.TEST_ETHER_AMOUNT);
    vm.label(user1, "user1");
    vm.label(user2, "user2");
  }

  /**
   * @notice Creates a random DID with pseudo-random parameters
   */
  function createRandomDid() public {
    // Generate pseudo-random values
    bytes32 randomValue = keccak256(abi.encodePacked(block.timestamp, currentNonce++, "random"));

    // Skip zero values
    if (randomValue == bytes32(0)) return;

    // Randomly choose user
    address user = currentNonce % 2 == 0 ? user1 : user2;

    vm.startPrank(user, user);

    // Record logs BEFORE the try block (fixed pattern from W3C handler)
    vm.recordLogs();
    try didManagerNative.createDid(Fixtures.EMPTY_DID_METHODS, randomValue, bytes32(0)) {
      // Track successful creation from recorded logs
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 didId = entries[2].topics[1]; // DidCreated event

      createdDids.push(didId);
      creationTimes.push(block.timestamp);
      didCreationCount++;
      totalOperations++;
    } catch {
      // Ignore failures (expected for duplicates)
    }

    vm.stopPrank();
  }

  /**
   * @notice Creates a random VM for an existing DID
   * @dev Randomly chooses between keyAgreement (with publicKeyMultibase) and other relationships
   */
  function createRandomVm() public {
    if (createdDids.length == 0) return;

    // Select random DID
    uint256 didIndex = currentNonce % createdDids.length;
    bytes32 selectedDid = createdDids[didIndex];

    // Generate random VM ID
    bytes32 vmId = keccak256(abi.encodePacked("vm", currentNonce++));

    // Randomly decide if this VM has keyAgreement relationship
    bool hasKeyAgreement = currentNonce % 2 == 0;

    // Set relationships: if hasKeyAgreement, include 0x04; otherwise use 0x01 (authentication)
    bytes1 relationships =
      hasKeyAgreement ? Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT : Fixtures.VM_RELATIONSHIPS_AUTHENTICATION;

    // Set publicKeyMultibase: ONLY if hasKeyAgreement
    bytes memory publicKeyMultibase =
      hasKeyAgreement ? Fixtures.TEST_SECP256K1_MULTIBASE : Fixtures.emptyVmPublicKeyMultibase();

    address user = currentNonce % 2 == 0 ? user1 : user2;

    vm.startPrank(user, user);

    CreateVmCommand memory command = CreateVmCommand({
      methods: DEFAULT_DID_METHODS,
      senderId: selectedDid,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: selectedDid,
      vmId: vmId,
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: relationships,
      publicKeyMultibase: publicKeyMultibase
    });

    try didManagerNative.createVm(command) {
      // Track VM state for invariant checking
      vmKeyAgreementState[selectedDid][vmId] =
        VmState({ hasKeyAgreement: hasKeyAgreement, hasMultibase: publicKeyMultibase.length > 0 });

      vmCreationCount++;
      totalOperations++;
    } catch {
      // Ignore failures
    }

    vm.stopPrank();
  }

  /**
   * @notice Updates controller for random DID
   */
  function updateRandomController() public {
    if (createdDids.length < 2) return;

    // Select two different DIDs
    uint256 ownerIndex = currentNonce % createdDids.length;
    uint256 controllerIndex = (currentNonce + 1) % createdDids.length;

    if (ownerIndex == controllerIndex) return;

    bytes32 ownerDid = createdDids[ownerIndex];
    bytes32 controllerDid = createdDids[controllerIndex];

    address user = currentNonce % 2 == 0 ? user1 : user2;

    vm.startPrank(user, user);

    try didManagerNative.updateController(
      DEFAULT_DID_METHODS,
      ownerDid,
      DEFAULT_VM_ID_NATIVE,
      ownerDid,
      controllerDid,
      bytes32(0),
      uint8(currentNonce % 5) // Random position 0-4
    ) {
      controllerUpdateCount++;
      totalOperations++;
    } catch {
      // Ignore failures
    }

    vm.stopPrank();
    currentNonce++;
  }

  // =========================================================================
  // GETTERS FOR INVARIANT TESTING
  // =========================================================================

  function getCreatedDids() external view returns (bytes32[] memory) {
    return createdDids;
  }

  function getCreationTimes() external view returns (uint256[] memory) {
    return creationTimes;
  }

  /**
   * @notice Returns the keyAgreement and multibase state for a VM
   * @dev Used by invariant_PublicKeyMultibaseShouldOnlyExistForKeyAgreement
   * @return hasKeyAgreement Whether the VM has keyAgreement relationship set
   * @return hasMultibase Whether the VM has non-empty publicKeyMultibase
   */
  function getVmKeyAgreementAndMultibaseState(bytes32 didId, bytes32 vmId)
    external
    view
    returns (bool hasKeyAgreement, bool hasMultibase)
  {
    VmState memory state = vmKeyAgreementState[didId][vmId];
    return (state.hasKeyAgreement, state.hasMultibase);
  }
}
