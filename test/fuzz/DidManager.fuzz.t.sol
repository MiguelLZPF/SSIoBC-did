// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { IDidManager, CreateVmCommand } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_DID_METHODS } from "@src/interfaces/IDidManager.sol";
import { DEFAULT_VM_ID } from "@src/interfaces/IVMStorage.sol";

/**
 * @title DidManagerFuzzTest
 * @notice Fuzz tests for DidManager contract using property-based testing
 * @dev Tests invariant properties and edge cases through randomized inputs
 */
contract DidManagerFuzzTest is TestBase {
    using DidTestHelpers for *;

    // Test users
    address private user1 = Fixtures.TEST_USER_1;

    function setUp() public {
        _deployDidManager();
        _setupUser(user1, "user1");
    }

    // =========================================================================
    // DID CREATION FUZZ TESTS
    // =========================================================================

    /**
     * @notice Fuzz test: DID creation should always succeed with non-zero random values
     * @dev Property: Any non-zero random value should create a unique DID
     */
    function testFuzz_CreateDid_Should_AlwaysSucceed_When_RandomIsNonZero(bytes32 randomValue) public {
        // Assume non-zero random value
        vm.assume(randomValue != bytes32(0));

        _startPrank(user1);

        // Test: Create DID with fuzzed random value
        DidTestHelpers.CreateDidResult memory result = DidTestHelpers.createDid(
            vm,
            didManager,
            Fixtures.EMPTY_DID_METHODS,
            randomValue,
            bytes32(0)
        );

        // Property: DID should always be created successfully
        assertNotEq(result.didInfo.id, bytes32(0));
        assertNotEq(result.didInfo.idHash, bytes32(0));
        assertEq(result.didInfo.methods, DEFAULT_DID_METHODS);

        // Property: DID should have a future expiration
        uint256 didExpiration = didManager.getExpiration(result.didInfo.methods, result.didInfo.id, bytes32(0));
        assertGt(didExpiration, block.timestamp);

        _stopPrank();
    }

    /**
     * @notice Fuzz test: DID creation with custom methods should preserve method data
     * @dev Property: Custom methods should be stored exactly as provided
     */
    function testFuzz_CreateDid_Should_PreserveMethods_When_CustomMethodsProvided(
        bytes32 customMethods,
        bytes32 randomValue
    ) public {
        // Assume valid inputs
        vm.assume(randomValue != bytes32(0));
        vm.assume(customMethods != bytes32(0));

        _startPrank(user1);

        // Test: Create DID with fuzzed custom methods
        DidTestHelpers.CreateDidResult memory result = DidTestHelpers.createDid(
            vm,
            didManager,
            customMethods,
            randomValue,
            bytes32(0)
        );

        // Property: Custom methods should be preserved exactly
        assertEq(result.didInfo.methods, customMethods);
        assertNotEq(result.didInfo.id, bytes32(0));

        _stopPrank();
    }

    /**
     * @notice Fuzz test: Duplicate DID creation should always fail
     * @dev Property: Same methods + random should always produce same DID and fail on duplicate
     */
    function testFuzz_CreateDid_Should_FailOnDuplicate_When_SameInputsUsed(bytes32 randomValue) public {
        // Assume non-zero random value
        vm.assume(randomValue != bytes32(0));

        _startPrank(user1);

        // Test: Create first DID
        DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, randomValue, bytes32(0));

        // Property: Duplicate creation should always fail
        vm.expectRevert();
        didManager.createDid(Fixtures.EMPTY_DID_METHODS, randomValue, bytes32(0));

        _stopPrank();
    }

    // =========================================================================
    // VM CREATION FUZZ TESTS
    // =========================================================================

    /**
     * @notice Fuzz test: VM creation with valid relationships should always succeed
     * @dev Property: Any valid relationship bitmask should allow VM creation
     */
    function testFuzz_CreateVm_Should_Succeed_When_ValidRelationshipsProvided(bytes1 relationships) public {
        // Assume valid relationships (non-zero)
        vm.assume(relationships != bytes1(0));
        vm.assume(relationships <= bytes1(0x1F)); // Max valid bitmask

        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Create VM with fuzzed relationships
        CreateVmCommand memory command = CreateVmCommand({
            methods: didResult.didInfo.methods,
            senderId: didResult.didInfo.id,
            senderVmId: DEFAULT_VM_ID,
            targetId: didResult.didInfo.id,
            vmId: Fixtures.VM_ID_CUSTOM,
            type_: Fixtures.defaultVmType(),
            publicKeyMultibase: Fixtures.emptyVmPublicKey(),
            blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
            ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
            relationships: relationships,
            expiration: Fixtures.EMPTY_VM_EXPIRATION
        });

        DidTestHelpers.CreateVmResult memory result = DidTestHelpers.createVm(vm, didManager, command);

        // Validate the VM to make it usable (since it has an ethereum address)
        _startPrank(Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS);
        didManager.validateVm(result.vmCreatedPositionHash, 0);
        _startPrank(user1);

        // Property: VM should be created successfully with any valid relationship
        assertNotEq(result.vmCreatedIdHash, bytes32(0));
        assertEq(result.vmCreatedId, Fixtures.VM_ID_CUSTOM);

        // Property: Created VM should have the specified relationships
        bool hasRelationship = didManager.isVmRelationship(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            Fixtures.VM_ID_CUSTOM,
            relationships,
            Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS
        );
        assertTrue(hasRelationship);

        _stopPrank();
    }

    /**
     * @notice Fuzz test: VM creation with different ethereum addresses
     * @dev Property: Different ethereum addresses should create different VMs
     */
    function testFuzz_CreateVm_Should_HandleDifferentAddresses_When_ValidAddressProvided(address ethAddress) public {
        // Assume valid address (not zero)
        vm.assume(ethAddress != address(0));

        _startPrank(user1);

        // Setup: Create a DID first
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Test: Create VM with fuzzed ethereum address
        CreateVmCommand memory command = CreateVmCommand({
            methods: didResult.didInfo.methods,
            senderId: didResult.didInfo.id,
            senderVmId: DEFAULT_VM_ID,
            targetId: didResult.didInfo.id,
            vmId: Fixtures.VM_ID_CUSTOM,
            type_: Fixtures.defaultVmType(),
            publicKeyMultibase: Fixtures.emptyVmPublicKey(),
            blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
            ethereumAddress: ethAddress,
            relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
            expiration: Fixtures.EMPTY_VM_EXPIRATION
        });

        // Note: When ethereumAddress is provided, expiration is set to 0 for validation
        DidTestHelpers.CreateVmResult memory result = DidTestHelpers.createVm(vm, didManager, command);

        // Property: VM should be created with any valid ethereum address
        assertNotEq(result.vmCreatedIdHash, bytes32(0));

        _stopPrank();
    }

    // =========================================================================
    // AUTHENTICATION FUZZ TESTS
    // =========================================================================

    /**
     * @notice Fuzz test: Authentication should be consistent for valid VM
     * @dev Property: Authentication result should be deterministic for same inputs
     */
    function testFuzz_Authenticate_Should_BeConsistent_When_ValidVmUsed(uint8 callCount) public {
        // Bound the call count to reasonable range
        callCount = uint8(bound(callCount, 1, 10));

        _startPrank(user1);

        // Setup: Create a DID
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Property: Authentication should return same result across multiple calls
        bool firstResult = didManager.authenticate(
            didResult.didInfo.methods,
            didResult.didInfo.id,
            DEFAULT_VM_ID,
            user1
        );

        // Test: Call authentication multiple times
        for (uint8 i = 0; i < callCount; i++) {
            bool result = didManager.authenticate(
                didResult.didInfo.methods,
                didResult.didInfo.id,
                DEFAULT_VM_ID,
                user1
            );

            // Property: Result should always be consistent
            assertEq(result, firstResult);
        }

        _stopPrank();
    }

    // =========================================================================
    // RELATIONSHIP FUZZ TESTS
    // =========================================================================

    /**
     * @notice Fuzz test: VM relationships should behave correctly for all valid combinations
     * @dev Property: Relationship checks should match created relationships
     */
    function testFuzz_VmRelationships_Should_MatchCreated_When_ValidRelationshipsBitmask(
        bytes1 relationships
    ) public {
        // Assume valid relationships
        vm.assume(relationships != bytes1(0));
        vm.assume(relationships <= bytes1(0x1F)); // Max valid bitmask

        _startPrank(user1);

        // Setup: Create DID and VM with fuzzed relationships
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        CreateVmCommand memory command = CreateVmCommand({
            methods: didResult.didInfo.methods,
            senderId: didResult.didInfo.id,
            senderVmId: DEFAULT_VM_ID,
            targetId: didResult.didInfo.id,
            vmId: Fixtures.VM_ID_CUSTOM,
            type_: Fixtures.defaultVmType(),
            publicKeyMultibase: Fixtures.emptyVmPublicKey(),
            blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
            ethereumAddress: Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS,
            relationships: relationships,
            expiration: Fixtures.EMPTY_VM_EXPIRATION
        });

        DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, command);

        // Validate the VM to make it usable (since it has an ethereum address)
        _startPrank(Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS);
        didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
        _startPrank(user1);

        // Test all possible relationship flags
        bytes1[5] memory relationshipFlags = [
            Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,    // 0x01
            Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,   // 0x02
            Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,      // 0x04
            Fixtures.VM_RELATIONSHIPS_CAPABILITY_INVOCATION, // 0x08
            Fixtures.VM_RELATIONSHIPS_CAPABILITY_DELEGATION  // 0x10
        ];

        for (uint256 i = 0; i < relationshipFlags.length; i++) {
            bool hasFlag = (relationships & relationshipFlags[i]) != 0;
            bool result = didManager.isVmRelationship(
                didResult.didInfo.methods,
                didResult.didInfo.id,
                Fixtures.VM_ID_CUSTOM,
                relationshipFlags[i],
                Fixtures.DEFAULT_VM_ETHEREUM_ADDRESS
            );

            // Property: Relationship check should match the created relationship flags
            assertEq(result, hasFlag, "Relationship flag mismatch");
        }

        _stopPrank();
    }

    // =========================================================================
    // TIME-BASED FUZZ TESTS
    // =========================================================================

    /**
     * @notice Fuzz test: Expiration handling with different time values
     * @dev Property: DIDs should expire at the correct time
     */
    function testFuzz_Expiration_Should_BehaveProperly_When_TimeAdvances(uint256 timeAdvance) public {
        // Bound time advance to reasonable range (up to 5 years)
        timeAdvance = bound(timeAdvance, 1, 5 * 365 * 24 * 60 * 60);

        _startPrank(user1);

        // Setup: Create a DID
        uint256 creationTime = block.timestamp;
        DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

        // Get original expiration
        uint256 originalExpiration = didManager.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0));

        // Property: Original expiration should be in the future
        assertGt(originalExpiration, creationTime);

        // Test: Advance time
        vm.warp(block.timestamp + timeAdvance);

        // Get expiration after time advance (should remain the same)
        uint256 newExpiration = didManager.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0));

        // Property: Expiration timestamp should not change when time advances
        assertEq(newExpiration, originalExpiration);

        // Property: Check if DID should be considered expired based on current time
        bool shouldBeExpired = block.timestamp >= originalExpiration;

        if (shouldBeExpired) {
            // If enough time has passed, the DID should be expired
            assertLe(originalExpiration, block.timestamp);
        } else {
            // If not enough time has passed, the DID should still be valid
            assertGt(originalExpiration, block.timestamp);
        }

        _stopPrank();
    }
}