// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { DidTestHelpers } from "@test/helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "@test/helpers/DidTestHelpersNative.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import {
  MockERC1271Wallet,
  MockERC1271AlwaysReject,
  MockERC1271Reverting,
  MockNotAWallet
} from "@test/mocks/MockERC1271Wallets.sol";
import { DEFAULT_VM_ID } from "@interfaces/IVMStorage.sol";
import { DEFAULT_VM_ID_NATIVE } from "@interfaces/IVMStorageNative.sol";
import "@types/DidTypes.sol";

/// @dev Packs a `vm.sign` triple into the 65-byte `r || s || v` layout ERC-2098/ECDSA expects.
function packSignature(uint8 v, bytes32 r, bytes32 s) pure returns (bytes memory) {
  return abi.encodePacked(r, s, v);
}

// =========================================================================
// Full W3C Variant
// =========================================================================

contract AuthorizeOffChainErc1271UnitTest is TestBase {
  address internal user1;
  address internal user2;

  bytes32 internal constant MESSAGE_HASH = keccak256("erc1271-challenge-message");

  function setUp() public {
    _deployDidManager();
    user1 = vm.addr(Fixtures.TEST_PK_1);
    user2 = vm.addr(Fixtures.TEST_PK_2);
    _setupUser(user1, "User1-PK");
    _setupUser(user2, "User2-PK");
  }

  function _createSelfDid() internal returns (DidTestHelpers.CreateDidResult memory didResult) {
    _startPrank(user1);
    didResult = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();
  }

  function _check(DidTestHelpers.CreateDidResult memory didResult, address signer, bytes memory signature)
    internal
    view
    returns (bool)
  {
    return didManager.isAuthorizedOffChainWithSigner(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      signer,
      MESSAGE_HASH,
      signature
    );
  }

  // ---------------------------------------------------------------------
  // EOA path (backwards compatibility with the v,r,s entry point)
  // ---------------------------------------------------------------------

  /// @notice A plain EOA signature in `bytes` form authorizes exactly like the v,r,s variant.
  function test_WithSigner_Should_ReturnTrue_When_EoaSignsWithBytesSignature() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    assertTrue(_check(didResult, user1, packSignature(v, r, s)), "EOA bytes signature should authorize");
  }

  /// @notice The bytes overload and the v,r,s overload agree for the same EOA signature.
  function test_WithSigner_Should_MatchLegacyOverload_When_EoaSigns() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    bool legacy = didManager.isAuthorizedOffChain(
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
    assertEq(_check(didResult, user1, packSignature(v, r, s)), legacy, "Both overloads must agree");
  }

  /// @notice A signature from another key does not authorize the claimed signer.
  function test_WithSigner_Should_ReturnFalse_When_EoaSignatureFromDifferentKey() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Mismatched signer must not authorize");
  }

  /// @notice A valid signature from a key that owns no VM in this DID does not authorize.
  function test_WithSigner_Should_ReturnFalse_When_SignerOwnsNoVm() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    assertFalse(_check(didResult, user2, packSignature(v, r, s)), "Unrelated signer must not authorize");
  }

  // ---------------------------------------------------------------------
  // ERC-1271 contract-signer path (EIP-7702 delegated EOA shape)
  // ---------------------------------------------------------------------

  /// @notice An account that gained code (EIP-7702) authorizes via ERC-1271 with its owner's key.
  function test_WithSigner_Should_ReturnTrue_When_Erc1271WalletApprovesSignature() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();

    // user1's VM is already active; user1 then "upgrades in place" into a smart account
    // whose signing authority is user2's key.
    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);
    assertTrue(_check(didResult, user1, packSignature(v, r, s)), "ERC-1271 wallet signature should authorize");
  }

  /// @notice The raw ecrecover entry point cannot see the ERC-1271 signature at all.
  function test_LegacyOverload_Should_ReturnFalse_When_SignerIsErc1271Wallet() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);
    bool legacy = didManager.isAuthorizedOffChain(
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
    assertFalse(legacy, "ecrecover path cannot validate a contract signature");
  }

  /// @notice A wallet rejecting the signature (wrong owner key) does not authorize.
  function test_WithSigner_Should_ReturnFalse_When_Erc1271WalletRejectsSignature() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Wallet rejects -> not authorized");
  }

  /// @notice A wallet returning a non-magic value does not authorize.
  function test_WithSigner_Should_ReturnFalse_When_Erc1271ReturnsWrongMagicValue() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271AlwaysReject wallet = new MockERC1271AlwaysReject();
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Wrong magic value -> not authorized");
  }

  /// @notice A reverting `isValidSignature` is swallowed, not bubbled — the view returns false.
  function test_WithSigner_Should_ReturnFalse_When_Erc1271Reverts() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Reverting wallet = new MockERC1271Reverting();
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Reverting wallet must not bubble up");
  }

  /// @notice A contract without `isValidSignature` does not authorize.
  function test_WithSigner_Should_ReturnFalse_When_ContractIsNotAWallet() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockNotAWallet notAWallet = new MockNotAWallet();
    vm.etch(user1, address(notAWallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Non-wallet contract must not authorize");
  }

  // ---------------------------------------------------------------------
  // Parameter validation
  // ---------------------------------------------------------------------

  function test_RevertWhen_WithSigner_SignerIsZero() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    vm.expectRevert(MissingRequiredParameter.selector);
    _check(didResult, address(0), packSignature(v, r, s));
  }

  function test_RevertWhen_WithSigner_MessageHashIsZero() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    vm.expectRevert(MissingRequiredParameter.selector);
    didManager.isAuthorizedOffChainWithSigner(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      user1,
      bytes32(0),
      packSignature(v, r, s)
    );
  }

  function test_RevertWhen_WithSigner_SignatureIsEmpty() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();

    vm.expectRevert(MissingRequiredParameter.selector);
    _check(didResult, user1, "");
  }

  /// @notice A malformed (wrong length) signature returns false rather than reverting.
  function test_WithSigner_Should_ReturnFalse_When_SignatureLengthIsInvalid() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();

    assertFalse(_check(didResult, user1, hex"deadbeef"), "Malformed signature must not authorize");
  }
}

// =========================================================================
// Ethereum-Native Variant
// =========================================================================

contract AuthorizeOffChainErc1271NativeUnitTest is TestBaseNative {
  address internal user1;
  address internal user2;

  bytes32 internal constant MESSAGE_HASH = keccak256("erc1271-challenge-message");

  function setUp() public {
    _deployDidManagerNative();
    user1 = vm.addr(Fixtures.TEST_PK_1);
    user2 = vm.addr(Fixtures.TEST_PK_2);
    _setupUser(user1, "User1-PK");
    _setupUser(user2, "User2-PK");
  }

  function _createSelfDid() internal returns (DidTestHelpersNative.CreateDidResult memory didResult) {
    _startPrank(user1);
    didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();
  }

  function _check(DidTestHelpersNative.CreateDidResult memory didResult, address signer, bytes memory signature)
    internal
    view
    returns (bool)
  {
    return didManagerNative.isAuthorizedOffChainWithSigner(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      signer,
      MESSAGE_HASH,
      signature
    );
  }

  function test_Native_WithSigner_Should_ReturnTrue_When_EoaSignsWithBytesSignature() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    assertTrue(_check(didResult, user1, packSignature(v, r, s)), "EOA bytes signature should authorize");
  }

  function test_Native_WithSigner_Should_ReturnTrue_When_Erc1271WalletApprovesSignature() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);
    assertTrue(_check(didResult, user1, packSignature(v, r, s)), "ERC-1271 wallet signature should authorize");
  }

  function test_Native_WithSigner_Should_ReturnFalse_When_Erc1271WalletRejectsSignature() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Wallet rejects -> not authorized");
  }

  function test_Native_WithSigner_Should_ReturnFalse_When_Erc1271Reverts() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Reverting wallet = new MockERC1271Reverting();
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Reverting wallet must not bubble up");
  }

  function test_Native_WithSigner_Should_ReturnFalse_When_SignerOwnsNoVm() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);

    assertFalse(_check(didResult, user2, packSignature(v, r, s)), "Unrelated signer must not authorize");
  }

  function test_Native_RevertWhen_WithSigner_SignerIsZero() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    vm.expectRevert(MissingRequiredParameter.selector);
    _check(didResult, address(0), packSignature(v, r, s));
  }

  function test_Native_RevertWhen_WithSigner_SignatureIsEmpty() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();

    vm.expectRevert(MissingRequiredParameter.selector);
    _check(didResult, user1, "");
  }
}
