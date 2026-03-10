// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { DidTestHelpers } from "@test/helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "@test/helpers/DidTestHelpersNative.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { DidCreateVmCommandNative as NativeCreateVmCommand } from "@types/VmTypesNative.sol";
import { DEFAULT_VM_ID } from "@interfaces/IVMStorage.sol";
import { DEFAULT_VM_ID_NATIVE } from "@interfaces/IVMStorageNative.sol";
import "@types/DidTypes.sol";

// =========================================================================
// Full W3C Variant Tests
// =========================================================================

contract AuthorizeOffChainUnitTest is TestBase {
  // Derived from private keys in setUp()
  address internal user1;
  address internal user2;
  address internal user3;

  bytes32 internal constant MESSAGE_HASH = keccak256("test-challenge-message");

  function setUp() public {
    _deployDidManager();
    user1 = vm.addr(Fixtures.TEST_PK_1);
    user2 = vm.addr(Fixtures.TEST_PK_2);
    user3 = vm.addr(Fixtures.TEST_PK_3);
    _setupUser(user1, "User1-PK");
    _setupUser(user2, "User2-PK");
    _setupUser(user3, "User3-PK");
  }

  // =========================================================================
  // HAPPY PATHS
  // =========================================================================

  /// @notice Self-controlled DID with authentication relationship → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_SelfControlledWithAuthentication() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Self-controlled DID with authentication should be authorized off-chain");
  }

  /// @notice Self-controlled DID with assertionMethod → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_SelfControlledWithAssertionMethod() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create VM with auth + assertion (0x03)
    _stopPrank();
    _startPrank(user1);
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-assertion"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-assertion"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Self-controlled DID with assertionMethod should be authorized off-chain");
  }

  /// @notice Controller-managed DID, controller has assertionMethod → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_ControllerHasAssertionMethod() public {
    // Create target DID as user1
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Create controller DID as user2 with auth + assertion VM
    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));

    CreateVmCommand memory cmd = CreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-assertion"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    // Set user2's DID as controller of user1's DID
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      bytes32("vm-assertion"),
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Controller with assertionMethod should be authorized off-chain");
  }

  /// @notice Controller without VM restriction (vmId=0), any VM works → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_ControllerWithoutVmRestriction() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set controller with vmId=0 (any VM accepted)
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Controller with no VM restriction should be authorized off-chain");
  }

  // =========================================================================
  // AUTHORIZATION FAILURES (return false, NOT revert)
  // =========================================================================

  /// @notice Invalid signature (garbled v/r/s → address(0)) → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_InvalidSignature() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Use invalid v value (not 27 or 28) to force ecrecover to return address(0)
    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      0, // invalid v
      bytes32(uint256(1)),
      bytes32(uint256(1))
    );
    assertFalse(authorized, "Invalid signature should not be authorized");
  }

  /// @notice Valid signature but from wrong private key → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_WrongSigner() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Sign with user2's key, but DID VM is bound to user1's address
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Wrong signer should not be authorized");
  }

  /// @notice VM lacks requested relationship → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_VmLacksRequestedRelationship() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    // Default VM only has auth (0x01), asking for assertion (0x02)
    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "VM without assertion should not be authorized for assertion off-chain");
  }

  /// @notice Non-controller caller → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderIsNotController() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory nonControllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set a different controller (user3) so controllers list is non-empty
    _startPrank(user3);
    DidTestHelpers.CreateDidResult memory actualControllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0));
    _stopPrank();

    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      actualControllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    // user2 is NOT a controller
    bool authorized = didManager.isAuthorizedOffChain(
      targetDid.didInfo.methods,
      nonControllerDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Non-controller should not be authorized off-chain");
  }

  /// @notice Expired sender DID → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderDidExpired() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    // Warp past DID expiration
    vm.warp(block.timestamp + Fixtures.WARP_TO_EXPIRE_DID);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Expired sender DID should not be authorized off-chain");
  }

  /// @notice Expired target DID → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_TargetDidExpired() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory senderDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();

    // Set sender as controller of target
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      senderDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    // Controller deactivates target DID
    _startPrank(user2);
    didManager.deactivateDid(targetDid.didInfo.methods, senderDid.didInfo.id, DEFAULT_VM_ID, targetDid.didInfo.id);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      targetDid.didInfo.methods,
      senderDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Deactivated target DID should not be authorized off-chain");
  }

  /// @notice Deactivated sender DID → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderDidDeactivated() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    didManager.deactivateDid(didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, didResult.didInfo.id);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Deactivated sender DID should not be authorized off-chain");
  }

  /// @notice Expired VM on sender → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderVmExpired() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);

    // Create a VM with short expiration
    CreateVmCommand memory cmd = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-short-lived"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(block.timestamp + 100)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManager.validateVm(vmResult.vmCreatedPositionHash, block.timestamp + 100);
    vm.stopPrank();

    // Warp past VM expiration but before DID expiration
    vm.warp(block.timestamp + 200);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-short-lived"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Expired VM should not be authorized off-chain");
  }

  /// @notice Controller with VM restriction, wrong VM used → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_ControllerUsesWrongVm() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory targetDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory controllerDid =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));

    CreateVmCommand memory cmd = CreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-restricted"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    // Set controller with specific VM restriction
    _startPrank(user1);
    didManager.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32("vm-restricted"),
      0
    );
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    // Try with DEFAULT_VM_ID instead of vm-restricted
    bool authorized = didManager.isAuthorizedOffChain(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID,
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Controller with wrong VM should not be authorized off-chain");
  }

  // =========================================================================
  // INVALID INPUTS (revert)
  // =========================================================================

  /// @notice Missing parameters → revert MissingRequiredParameter
  function test_RevertWhen_IsAuthorizedOffChain_WithMissingParameters() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    // Zero messageHash
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      bytes32(0),
      v,
      r,
      s
    );

    // Zero r
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      bytes32(0),
      s
    );

    // Zero s
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      bytes32(0)
    );

    // Zero methods (delegated to _isAuthorized → _validateAuthorizedParams)
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      bytes32(0), didResult.didInfo.id, DEFAULT_VM_ID, didResult.didInfo.id, bytes1(0x01), MESSAGE_HASH, v, r, s
    );

    // Zero senderId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods, bytes32(0), DEFAULT_VM_ID, didResult.didInfo.id, bytes1(0x01), MESSAGE_HASH, v, r, s
    );

    // Zero senderVmId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32(0),
      didResult.didInfo.id,
      bytes1(0x01),
      MESSAGE_HASH,
      v,
      r,
      s
    );

    // Zero targetId
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID, bytes32(0), bytes1(0x01), MESSAGE_HASH, v, r, s
    );

    // Zero relationship
    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      bytes1(0),
      MESSAGE_HASH,
      v,
      r,
      s
    );
  }

  /// @notice Invalid relationship (0x20) → revert VmRelationshipOutOfRange
  function test_RevertWhen_IsAuthorizedOffChain_WithInvalidRelationship() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    vm.expectRevert(VmRelationshipOutOfRange.selector);
    didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_INVALID,
      MESSAGE_HASH,
      v,
      r,
      s
    );
  }

  // =========================================================================
  // CONSISTENCY: isAuthorizedOffChain matches isAuthorized
  // =========================================================================

  /// @notice For valid signature, isAuthorizedOffChain should return same result as isAuthorized
  function test_IsAuthorizedOffChain_Should_MatchIsAuthorized_When_ValidSignature() public {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool offChainResult = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );

    bool onChainResult = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1
    );

    assertEq(offChainResult, onChainResult, "Off-chain and on-chain auth results should match");
  }

  // =========================================================================
  // FUZZ TESTS
  // =========================================================================

  /// @notice Fuzz: for any valid PK+messageHash, offchain result matches onchain
  function testFuzz_IsAuthorizedOffChain_ShouldMatchIsAuthorized(uint256 privateKey, bytes32 msgHash) public {
    // Bound private key to valid range (1 to secp256k1 order - 1)
    privateKey = bound(privateKey, 1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140);
    vm.assume(msgHash != bytes32(0));

    address signer = vm.addr(privateKey);
    vm.deal(signer, 100 ether);

    // Create DID with signer's address
    vm.startPrank(signer);
    DidTestHelpers.CreateDidResult memory didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    vm.stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
    // vm.sign should produce valid r,s — skip if either is zero (extremely unlikely but possible)
    vm.assume(r != bytes32(0) && s != bytes32(0));

    bool offChainResult = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      msgHash,
      v,
      r,
      s
    );

    bool onChainResult = didManager.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      signer
    );

    assertEq(offChainResult, onChainResult, "Fuzz: off-chain and on-chain auth results should match");
  }
}

// =========================================================================
// Native Variant Tests
// =========================================================================

contract AuthorizeOffChainNativeUnitTest is TestBaseNative {
  address internal user1;
  address internal user2;
  address internal user3;

  bytes32 internal constant MESSAGE_HASH = keccak256("test-challenge-message");

  function setUp() public {
    _deployDidManagerNative();
    user1 = vm.addr(Fixtures.TEST_PK_1);
    user2 = vm.addr(Fixtures.TEST_PK_2);
    user3 = vm.addr(Fixtures.TEST_PK_3);
    _setupUser(user1, "User1-PK");
    _setupUser(user2, "User2-PK");
    _setupUser(user3, "User3-PK");
  }

  // =========================================================================
  // HAPPY PATHS
  // =========================================================================

  /// @notice Self-controlled DID with authentication relationship → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_SelfControlledWithAuthentication() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Self-controlled native DID with authentication should be authorized off-chain");
  }

  /// @notice Self-controlled DID with assertionMethod → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_SelfControlledWithAssertionMethod() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: didResult.didInfo.id,
      vmId: bytes32("vm-assertion"),
      ethereumAddress: user1,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user1);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      bytes32("vm-assertion"),
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Self-controlled native DID with assertionMethod should be authorized off-chain");
  }

  /// @notice Controller-managed DID → true
  function test_IsAuthorizedOffChain_Should_ReturnTrue_When_ControllerHasAssertionMethod() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory targetDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    NativeCreateVmCommand memory cmd = NativeCreateVmCommand({
      methods: controllerDid.didInfo.methods,
      senderId: controllerDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: controllerDid.didInfo.id,
      vmId: bytes32("vm-assertion"),
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, cmd);
    _stopPrank();
    vm.startPrank(user2);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);
    vm.stopPrank();

    _startPrank(user1);
    didManagerNative.updateController(
      targetDid.didInfo.methods,
      targetDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      targetDid.didInfo.id,
      controllerDid.didInfo.id,
      bytes32(0),
      0
    );
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    bool authorized = didManagerNative.isAuthorizedOffChain(
      targetDid.didInfo.methods,
      controllerDid.didInfo.id,
      bytes32("vm-assertion"),
      targetDid.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_ASSERTION_METHOD,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertTrue(authorized, "Controller with assertionMethod should be authorized off-chain (native)");
  }

  // =========================================================================
  // AUTHORIZATION FAILURES (return false, NOT revert)
  // =========================================================================

  /// @notice Invalid signature → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_InvalidSignature() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    bool authorized = didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      0,
      bytes32(uint256(1)),
      bytes32(uint256(1))
    );
    assertFalse(authorized, "Invalid signature should not be authorized (native)");
  }

  /// @notice Wrong signer → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_WrongSigner() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    bool authorized = didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Wrong signer should not be authorized (native)");
  }

  /// @notice Expired sender DID → false
  function test_IsAuthorizedOffChain_Should_ReturnFalse_When_SenderDidExpired() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    vm.warp(block.timestamp + Fixtures.WARP_TO_EXPIRE_DID);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool authorized = didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      s
    );
    assertFalse(authorized, "Expired sender DID should not be authorized off-chain (native)");
  }

  // =========================================================================
  // INVALID INPUTS (revert)
  // =========================================================================

  /// @notice Missing parameters → revert MissingRequiredParameter
  function test_RevertWhen_IsAuthorizedOffChain_WithMissingParameters() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    // Zero messageHash
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      bytes32(0),
      v,
      r,
      s
    );

    // Zero r
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      bytes32(0),
      s
    );

    // Zero s
    vm.expectRevert(MissingRequiredParameter.selector);
    didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      v,
      r,
      bytes32(0)
    );
  }

  /// @notice Invalid relationship → revert VmRelationshipOutOfRange
  function test_RevertWhen_IsAuthorizedOffChain_WithInvalidRelationship() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    vm.expectRevert(VmRelationshipOutOfRange.selector);
    didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_INVALID,
      MESSAGE_HASH,
      v,
      r,
      s
    );
  }

  // =========================================================================
  // CONSISTENCY: isAuthorizedOffChain matches isAuthorized
  // =========================================================================

  /// @notice Fuzz: for any valid PK+messageHash, offchain result matches onchain
  function testFuzz_IsAuthorizedOffChain_ShouldMatchIsAuthorized(uint256 privateKey, bytes32 msgHash) public {
    privateKey = bound(privateKey, 1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140);
    vm.assume(msgHash != bytes32(0));

    address signer = vm.addr(privateKey);
    vm.deal(signer, 100 ether);

    vm.startPrank(signer);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    vm.stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
    vm.assume(r != bytes32(0) && s != bytes32(0));

    bool offChainResult = didManagerNative.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      msgHash,
      v,
      r,
      s
    );

    bool onChainResult = didManagerNative.isAuthorized(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      signer
    );

    assertEq(offChainResult, onChainResult, "Fuzz: off-chain and on-chain auth results should match (native)");
  }
}
