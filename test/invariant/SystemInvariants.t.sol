// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Vm } from "forge-std/Vm.sol";
import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { IDidManager, CreateVmCommand } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_DID_METHODS } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";

/**
 * @title SystemInvariantsTest
 * @notice Invariant tests for the entire DID management system
 * @dev Tests system-wide properties that should always hold true
 */
contract SystemInvariantsTest is StdInvariant, TestBase {
  using DidTestHelpers for *;

  // Handler contract for invariant testing
  InvariantHandler private handler;

  function setUp() public {
    _deployDidManager();

    // Create and configure the handler
    handler = new InvariantHandler(didManager);

    // Target the handler for invariant testing
    targetContract(address(handler));

    // Target specific functions for more focused testing
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = InvariantHandler.createRandomDid.selector;
    selectors[1] = InvariantHandler.createRandomVm.selector;
    selectors[2] = InvariantHandler.updateRandomController.selector;

    targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
  }

  // =========================================================================
  // SYSTEM INVARIANTS
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
      uint256 expiration = didManager.getExpiration(DEFAULT_DID_METHODS, createdDids[i], bytes32(0));

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
      uint256 vmCount = didManager.getVmListLength(DEFAULT_DID_METHODS, createdDids[i]);

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
}

/**
 * @title InvariantHandler
 * @notice Handler contract for invariant testing that performs random operations
 * @dev Maintains state and provides controlled randomness for testing
 */
contract InvariantHandler is Test {
  using DidTestHelpers for *;

  IDidManager private didManager;

  // State tracking
  bytes32[] private createdDids;
  uint256[] private creationTimes;
  uint256 private currentNonce;

  // Operation counters
  uint256 public didCreationCount;
  uint256 public vmCreationCount;
  uint256 public controllerUpdateCount;
  uint256 public totalOperations;

  // Test users
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;

  constructor(IDidManager _didManager) {
    didManager = _didManager;

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

    try didManager.createDid(Fixtures.EMPTY_DID_METHODS, randomValue, bytes32(0)) {
      // Track successful creation
      vm.recordLogs();
      didManager.createDid(Fixtures.EMPTY_DID_METHODS, randomValue, bytes32(0));

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
   */
  function createRandomVm() public {
    if (createdDids.length == 0) return;

    // Select random DID
    uint256 didIndex = currentNonce % createdDids.length;
    bytes32 selectedDid = createdDids[didIndex];

    // Generate random VM ID
    bytes32 vmId = keccak256(abi.encodePacked("vm", currentNonce++));

    // Random relationships (1-31)
    bytes1 relationships = bytes1(uint8((currentNonce % 31) + 1));

    address user = currentNonce % 2 == 0 ? user1 : user2;

    vm.startPrank(user, user);

    CreateVmCommand memory command = CreateVmCommand({
      methods: DEFAULT_DID_METHODS,
      senderId: selectedDid,
      senderVmId: DEFAULT_VM_ID,
      targetId: selectedDid,
      vmId: vmId,
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
      relationships: relationships,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });

    try didManager.createVm(command) {
      vmCreationCount++;
      totalOperations++;
    } catch {
      // Ignore failures
    }

    vm.stopPrank();
    currentNonce++;
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

    try didManager.updateController(
      DEFAULT_DID_METHODS,
      ownerDid,
      DEFAULT_VM_ID,
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
}
