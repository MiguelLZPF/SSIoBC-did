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
  address internal user3;

  bytes32 internal constant MESSAGE_HASH = keccak256("erc1271-challenge-message");

  function setUp() public {
    _deployDidManager();
    user1 = vm.addr(Fixtures.TEST_PK_1);
    user2 = vm.addr(Fixtures.TEST_PK_2);
    user3 = vm.addr(Fixtures.TEST_PK_3);
    _setupUser(user1, "User1-PK");
    _setupUser(user2, "User2-PK");
    _setupUser(user3, "User3-PK");
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
    assertTrue(legacy, "Anchor: the legacy overload must authorize this signature");
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
  /// @dev The control below is what makes this test meaningful: the same signature is rejected by
  /// the legacy overload BEFORE any code is placed at user1, so the failure is attributable to
  /// ecrecover recovering user2 rather than to the wallet. The ERC-1271 branch is then shown to
  /// change nothing for the legacy path, while `test_WithSigner_Should_ReturnTrue_When_Erc1271...`
  /// shows the new overload does accept it.
  function test_LegacyOverload_Should_ReturnFalse_When_SignerIsErc1271Wallet() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_2, MESSAGE_HASH);
    assertFalse(
      _check(didResult, user1, packSignature(v, r, s)),
      "Control: before any code exists at user1, user2's signature must not authorize user1"
    );

    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);
    assertTrue(
      _check(didResult, user1, packSignature(v, r, s)),
      "Control: once user1 bears ERC-1271 code approving user2, the new overload authorizes"
    );

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

  /// @notice A wallet rejecting the signature does not authorize.
  /// @dev Signed with user3's key: neither the wallet's owner (user2) nor the account's own key
  /// (user1), so neither the ERC-1271 branch nor the EIP-7702 ECDSA fallback can accept it.
  function test_WithSigner_Should_ReturnFalse_When_Erc1271WalletRejectsSignature() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Wallet rejects -> not authorized");
  }

  /// @notice A wallet returning a non-magic value does not authorize.
  /// @dev Signed with user3's key so the EIP-7702 ECDSA fallback cannot mask the wallet's verdict.
  function test_WithSigner_Should_ReturnFalse_When_Erc1271ReturnsWrongMagicValue() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271AlwaysReject wallet = new MockERC1271AlwaysReject();
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Wrong magic value -> not authorized");
  }

  /// @notice A reverting `isValidSignature` is swallowed, not bubbled, and the view returns false.
  /// @dev Signed with user3's key so the EIP-7702 ECDSA fallback cannot mask the revert.
  function test_WithSigner_Should_ReturnFalse_When_Erc1271Reverts() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Reverting wallet = new MockERC1271Reverting();
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Reverting wallet must not bubble up");
  }

  /// @notice A contract without `isValidSignature`, signed by an unrelated key, does not authorize.
  /// @dev The same setup signed by the account's OWN key DOES authorize, via the EIP-7702 ECDSA
  /// fallback: see `test_WithSigner_Should_ReturnTrue_When_Delegate...`.
  function test_WithSigner_Should_ReturnFalse_When_ContractIsNotAWallet() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockNotAWallet notAWallet = new MockNotAWallet();
    vm.etch(user1, address(notAWallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Non-wallet contract must not authorize");
  }

  // ---------------------------------------------------------------------
  // EIP-7702 ECDSA fallback
  // ---------------------------------------------------------------------

  /// @notice An EOA delegated to a delegate that does NOT implement ERC-1271 still authorizes
  /// with its own key. Without the fallback, `SignatureChecker` takes the contract branch,
  /// staticcalls a function that does not exist, and returns false for a valid signature.
  /// Reproduced against the real cheatcode before the fallback existed: legacy `true`,
  /// this view `false`.
  function test_WithSigner_Should_ReturnTrue_When_DelegateLacksErc1271ButOwnKeySigns() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockNotAWallet notAWallet = new MockNotAWallet();
    vm.etch(user1, address(notAWallet).code);
    assertGt(user1.code.length, 0, "Precondition: user1 must carry code");

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);
    assertTrue(
      _check(didResult, user1, packSignature(v, r, s)), "A 7702-delegated EOA must still authorize with its own key"
    );
  }

  /// @notice The fallback does not let an unrelated key through: it recovers and compares.
  function test_WithSigner_Should_ReturnFalse_When_DelegateLacksErc1271AndForeignKeySigns() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    MockNotAWallet notAWallet = new MockNotAWallet();
    vm.etch(user1, address(notAWallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Foreign key must not pass the fallback");
  }

  /// @notice Documents the deliberate divergence: this view rejects a malleated (high-`s`)
  /// signature via OpenZeppelin ECDSA, while the raw-`ecrecover` overload accepts it.
  function test_WithSigner_Should_ReturnFalse_When_SignatureIsMalleated() public {
    DidTestHelpers.CreateDidResult memory didResult = _createSelfDid();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_1, MESSAGE_HASH);

    // secp256k1 group order; the malleated pair is (v flipped, r, n - s)
    uint256 n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    bytes32 sHigh = bytes32(n - uint256(s));
    uint8 vFlipped = v == 27 ? 28 : 27;

    bool legacy = didManager.isAuthorizedOffChain(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID,
      didResult.didInfo.id,
      Fixtures.VM_RELATIONSHIPS_AUTHENTICATION,
      MESSAGE_HASH,
      vFlipped,
      r,
      sHigh
    );
    assertTrue(legacy, "Anchor: the raw ecrecover overload accepts the malleated signature");
    assertFalse(_check(didResult, user1, packSignature(vFlipped, r, sHigh)), "This view must reject a high-s signature");
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
  address internal user3;

  bytes32 internal constant MESSAGE_HASH = keccak256("erc1271-challenge-message");

  function setUp() public {
    _deployDidManagerNative();
    user1 = vm.addr(Fixtures.TEST_PK_1);
    user2 = vm.addr(Fixtures.TEST_PK_2);
    user3 = vm.addr(Fixtures.TEST_PK_3);
    _setupUser(user1, "User1-PK");
    _setupUser(user2, "User2-PK");
    _setupUser(user3, "User3-PK");
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

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
    assertFalse(_check(didResult, user1, packSignature(v, r, s)), "Wallet rejects -> not authorized");
  }

  function test_Native_WithSigner_Should_ReturnFalse_When_Erc1271Reverts() public {
    DidTestHelpersNative.CreateDidResult memory didResult = _createSelfDid();
    MockERC1271Reverting wallet = new MockERC1271Reverting();
    vm.etch(user1, address(wallet).code);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(Fixtures.TEST_PK_3, MESSAGE_HASH);
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
