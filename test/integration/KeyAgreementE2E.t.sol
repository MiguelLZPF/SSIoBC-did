// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Vm } from "forge-std/Vm.sol";
import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidCreateVmCommandNative as CreateVmCommand } from "@types/VmTypesNative.sol";
import { DEFAULT_VM_ID_NATIVE } from "@types/VmTypesNative.sol";
import { W3CDidDocument, W3CDidInput } from "@types/W3CTypes.sol";

// =============================================================================
// Secp256k1 — Minimal EC math for ECDH in tests
// =============================================================================

/**
 * @title Secp256k1
 * @notice Minimal secp256k1 elliptic curve math for ECDH key exchange in tests.
 * @dev Uses the modexp precompile (0x05) for modular inverse via Fermat's little theorem.
 *      All subtraction uses addmod(a, P - b, P) to avoid underflow.
 */
library Secp256k1 {
  // secp256k1 field prime
  uint256 internal constant P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
  // secp256k1 group order
  uint256 internal constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
  // Generator point
  uint256 internal constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
  uint256 internal constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

  /**
   * @notice Modular inverse using modexp precompile (Fermat's little theorem: a^(p-2) mod p).
   */
  function modInverse(uint256 a, uint256 modulus) internal view returns (uint256 result) {
    // modexp precompile at address 0x05
    // Input: base_length(32) || exp_length(32) || mod_length(32) || base || exp || mod
    uint256 exponent = modulus - 2;
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, 0x20) // base length = 32 bytes
      mstore(add(ptr, 0x20), 0x20) // exponent length = 32 bytes
      mstore(add(ptr, 0x40), 0x20) // modulus length = 32 bytes
      mstore(add(ptr, 0x60), a) // base
      mstore(add(ptr, 0x80), exponent) // exponent = modulus - 2
      mstore(add(ptr, 0xa0), modulus) // modulus

      // Call modexp precompile at 0x05
      if iszero(staticcall(gas(), 0x05, ptr, 0xc0, ptr, 0x20)) { revert(0, 0) }
      result := mload(ptr)
    }
  }

  /**
   * @notice Elliptic curve point addition on secp256k1.
   * @dev Handles identity point (0,0) and delegates to ecDouble when points are equal.
   */
  function ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) internal view returns (uint256 x3, uint256 y3) {
    // Identity element
    if (x1 == 0 && y1 == 0) return (x2, y2);
    if (x2 == 0 && y2 == 0) return (x1, y1);

    // Same point → double
    if (x1 == x2 && y1 == y2) return ecDouble(x1, y1);

    // Inverse points → identity
    if (x1 == x2) return (0, 0);

    // lambda = (y2 - y1) / (x2 - x1) mod P
    uint256 num = addmod(y2, P - y1, P);
    uint256 den = addmod(x2, P - x1, P);
    uint256 lambda = mulmod(num, modInverse(den, P), P);

    // x3 = lambda^2 - x1 - x2
    x3 = addmod(mulmod(lambda, lambda, P), P - x1, P);
    x3 = addmod(x3, P - x2, P);

    // y3 = lambda * (x1 - x3) - y1
    y3 = mulmod(lambda, addmod(x1, P - x3, P), P);
    y3 = addmod(y3, P - y1, P);
  }

  /**
   * @notice Elliptic curve point doubling on secp256k1.
   * @dev lambda = 3*x^2 / (2*y) mod P. (a=0 for secp256k1)
   */
  function ecDouble(uint256 x, uint256 y) internal view returns (uint256 x3, uint256 y3) {
    if (y == 0) return (0, 0);

    // lambda = (3 * x^2) / (2 * y) mod P
    uint256 num = mulmod(3, mulmod(x, x, P), P);
    uint256 den = mulmod(2, y, P);
    uint256 lambda = mulmod(num, modInverse(den, P), P);

    // x3 = lambda^2 - 2*x
    x3 = addmod(mulmod(lambda, lambda, P), P - x, P);
    x3 = addmod(x3, P - x, P);

    // y3 = lambda * (x - x3) - y
    y3 = mulmod(lambda, addmod(x, P - x3, P), P);
    y3 = addmod(y3, P - y, P);
  }

  /**
   * @notice Scalar multiplication via double-and-add (LSB to MSB).
   */
  function ecMul(uint256 scalar, uint256 px, uint256 py) internal view returns (uint256 rx, uint256 ry) {
    // Result starts as identity
    rx = 0;
    ry = 0;
    uint256 qx = px;
    uint256 qy = py;

    while (scalar > 0) {
      if (scalar & 1 == 1) {
        (rx, ry) = ecAdd(rx, ry, qx, qy);
      }
      (qx, qy) = ecDouble(qx, qy);
      scalar >>= 1;
    }
  }

  /**
   * @notice ECDH: returns x-coordinate of scalar * (pubX, pubY).
   */
  function ecdh(uint256 privKey, uint256 pubX, uint256 pubY) internal view returns (uint256) {
    (uint256 sx,) = ecMul(privKey, pubX, pubY);
    return sx;
  }

  /**
   * @notice Compress a public key to 33 bytes (0x02/0x03 prefix + 32-byte x).
   */
  function compressPublicKey(uint256 x, uint256 y) internal pure returns (bytes memory) {
    bytes1 prefix = (y % 2 == 0) ? bytes1(0x02) : bytes1(0x03);
    return abi.encodePacked(prefix, bytes32(x));
  }

  /**
   * @notice Decompress a 33-byte compressed public key to (x, y).
   * @dev Computes y = sqrt(x^3 + 7) mod P using Tonelli-Shanks shortcut: P ≡ 3 (mod 4).
   */
  function decompressPublicKey(bytes memory compressed) internal view returns (uint256 x, uint256 y) {
    require(compressed.length == 33, "Invalid compressed key length");
    uint8 prefix = uint8(compressed[0]);
    require(prefix == 0x02 || prefix == 0x03, "Invalid prefix");

    // Extract x from bytes [1..32]
    bytes32 xBytes;
    assembly {
      xBytes := mload(add(compressed, 33))
    }
    x = uint256(xBytes);

    // y^2 = x^3 + 7 mod P
    uint256 ySq = addmod(mulmod(mulmod(x, x, P), x, P), 7, P);

    // y = ySq^((P+1)/4) mod P  (works because P ≡ 3 mod 4)
    uint256 sqrtExp = (P + 1) / 4;
    // Use modexp precompile
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, 0x20)
      mstore(add(ptr, 0x20), 0x20)
      mstore(add(ptr, 0x40), 0x20)
      mstore(add(ptr, 0x60), ySq)
      mstore(add(ptr, 0x80), sqrtExp)
      mstore(add(ptr, 0xa0), P)
      if iszero(staticcall(gas(), 0x05, ptr, 0xc0, ptr, 0x20)) { revert(0, 0) }
      y := mload(ptr)
    }

    // Select correct parity
    if (prefix == 0x02 && y % 2 != 0) {
      y = P - y;
    } else if (prefix == 0x03 && y % 2 == 0) {
      y = P - y;
    }
  }

  /**
   * @notice Encode a compressed public key as simplified multibase for native VM storage.
   * @dev Format: "z" + 0xe701 (secp256k1-pub multicodec) + compressed key.
   *      The contract validates: [0] == 'z' and length check. This encoding is valid.
   */
  function toMultibase(bytes memory compressed) internal pure returns (bytes memory) {
    return abi.encodePacked("z", bytes2(0xe701), compressed);
  }

  /**
   * @notice Decode a multibase-encoded key back to compressed public key.
   * @dev Strips the first 3 bytes ('z' + 2-byte multicodec prefix).
   */
  function fromMultibase(bytes memory multibase) internal pure returns (bytes memory) {
    require(multibase.length > 3, "Multibase too short");
    bytes memory compressed = new bytes(multibase.length - 3);
    for (uint256 i = 0; i < compressed.length; i++) {
      compressed[i] = multibase[i + 3];
    }
    return compressed;
  }
}

// =============================================================================
// SimpleEncryption — XOR-based symmetric cipher for demonstration
// =============================================================================

/**
 * @title SimpleEncryption
 * @notice XOR-based symmetric cipher for demonstrating ECDH shared secret usage.
 * @dev Counter-mode chaining for messages longer than 32 bytes.
 */
library SimpleEncryption {
  /**
   * @notice Derive a 32-byte symmetric key from an ECDH shared secret.
   */
  function deriveKey(uint256 sharedSecretX) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(sharedSecretX));
  }

  /**
   * @notice XOR cipher with counter-mode key expansion. Symmetric: encrypt == decrypt.
   */
  function xorCipher(bytes memory data, bytes32 key) internal pure returns (bytes memory result) {
    result = new bytes(data.length);
    uint256 blockIndex = 0;
    bytes32 keyBlock = keccak256(abi.encodePacked(key, blockIndex));

    for (uint256 i = 0; i < data.length; i++) {
      // Rotate key block every 32 bytes
      if (i > 0 && i % 32 == 0) {
        blockIndex++;
        keyBlock = keccak256(abi.encodePacked(key, blockIndex));
      }
      result[i] = data[i] ^ keyBlock[i % 32];
    }
  }
}

// =============================================================================
// KeyAgreementE2ETest — Full ECDH key exchange E2E integration test
// =============================================================================

/**
 * @title KeyAgreementE2ETest
 * @notice End-to-end integration test demonstrating real ECDH key exchange
 *         using on-chain DID keyAgreement verification methods.
 * @dev Flow: store public key on-chain → resolve DID document → extract key →
 *      ECDH shared secret → encrypt/decrypt message.
 */
contract KeyAgreementE2ETest is TestBaseNative {
  using DidTestHelpersNative for *;

  /// @dev Packed state to avoid stack-too-deep in the main E2E test.
  struct E2EState {
    uint256 alicePrivKey;
    uint256 alicePubX;
    uint256 alicePubY;
    address aliceAddr;
    uint256 bobPrivKey;
    uint256 bobPubX;
    uint256 bobPubY;
    bytes aliceMultibase;
    bytes32 didMethods;
    bytes32 didId;
  }

  function setUp() public {
    _deployDidManagerNative();
  }

  // =========================================================================
  // MAIN E2E TEST
  // =========================================================================

  function test_KeyAgreement_ECDH_E2E_Should_EncryptAndDecrypt_When_SharedSecretDerived() public {
    E2EState memory s;

    // === Phase 0: Key Generation & EC Math Validation ===
    {
      Vm.Wallet memory aliceWallet = vm.createWallet(0xA11CE);
      Vm.Wallet memory bobWallet = vm.createWallet(0xB0B);

      s.alicePrivKey = aliceWallet.privateKey;
      s.alicePubX = aliceWallet.publicKeyX;
      s.alicePubY = aliceWallet.publicKeyY;
      s.aliceAddr = aliceWallet.addr;
      s.bobPrivKey = bobWallet.privateKey;
      s.bobPubX = bobWallet.publicKeyX;
      s.bobPubY = bobWallet.publicKeyY;

      _setupUser(aliceWallet.addr, "Alice");
      _setupUser(bobWallet.addr, "Bob");

      // Validate our EC math matches Foundry's libsecp256k1
      (uint256 derivedX, uint256 derivedY) = Secp256k1.ecMul(s.alicePrivKey, Secp256k1.GX, Secp256k1.GY);
      assertEq(derivedX, s.alicePubX, "EC math X mismatch for Alice");
      assertEq(derivedY, s.alicePubY, "EC math Y mismatch for Alice");
    }

    // === Phase 1: Alice Creates DID with keyAgreement VM ===
    _createAliceDidWithKeyAgreement(s);

    // === Phase 2: Bob Resolves Alice's DID Document ===
    string memory resolvedPubKeyMultibase = _resolveAndVerifyDocument(s);

    // === Phase 3: Bob Extracts Alice's Public Key from DID Document ===
    _extractAndVerifyPublicKey(s, resolvedPubKeyMultibase);

    // === Phase 4 & 5: ECDH Key Exchange + Encrypted Communication ===
    _ecdhAndEncrypt(s);
  }

  function _createAliceDidWithKeyAgreement(E2EState memory s) internal {
    _startPrank(s.aliceAddr);

    DidTestHelpersNative.CreateDidResult memory aliceDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0)
    );

    s.didMethods = aliceDid.didInfo.methods;
    s.didId = aliceDid.didInfo.id;

    // Compress Alice's public key and encode as multibase
    bytes memory aliceCompressed = Secp256k1.compressPublicKey(s.alicePubX, s.alicePubY);
    s.aliceMultibase = Secp256k1.toMultibase(aliceCompressed);

    // Create a VM with auth + keyAgreement (0x05) and Alice's public key
    CreateVmCommand memory vmCommand = CreateVmCommand({
      methods: s.didMethods,
      senderId: s.didId,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: s.didId,
      vmId: bytes32("key-agreement-vm"),
      ethereumAddress: s.aliceAddr,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_KEY_AGREEMENT,
      publicKeyMultibase: s.aliceMultibase
    });

    vm.recordLogs();
    didManagerNative.createVm(vmCommand);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);

    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    // Verify the VM is valid
    assertTrue(
      didManagerNative.isVmRelationship(
        s.didMethods, s.didId, bytes32("key-agreement-vm"), Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT, s.aliceAddr
      ),
      "Alice's keyAgreement VM should be valid"
    );
  }

  function _resolveAndVerifyDocument(E2EState memory s) internal view returns (string memory resolvedPubKeyMultibase) {
    W3CDidInput memory aliceDidInput = W3CDidInput({ methods: s.didMethods, id: s.didId, fragment: bytes32(0) });
    W3CDidDocument memory doc = w3cResolverNative.resolve(aliceDidInput, false);

    assertEq(doc.keyAgreement.length, 1, "Should have 1 keyAgreement entry");
    assertEq(doc.verificationMethod.length, 2, "Should have 2 VMs (default + keyAgreement)");

    resolvedPubKeyMultibase = doc.verificationMethod[1].publicKeyMultibase;
    assertGt(bytes(resolvedPubKeyMultibase).length, 0, "publicKeyMultibase should be non-empty");
    assertEq(
      keccak256(bytes(resolvedPubKeyMultibase)),
      keccak256(s.aliceMultibase),
      "Resolved publicKeyMultibase should match stored value"
    );
  }

  function _extractAndVerifyPublicKey(E2EState memory s, string memory resolvedPubKeyMultibase) internal view {
    bytes memory resolvedCompressed = Secp256k1.fromMultibase(bytes(resolvedPubKeyMultibase));
    (uint256 recoveredX, uint256 recoveredY) = Secp256k1.decompressPublicKey(resolvedCompressed);

    assertEq(recoveredX, s.alicePubX, "Recovered X should match Alice's public key X");
    assertEq(recoveredY, s.alicePubY, "Recovered Y should match Alice's public key Y");
  }

  function _ecdhAndEncrypt(E2EState memory s) internal view {
    // ECDH key exchange
    uint256 sharedSecretBob = Secp256k1.ecdh(s.bobPrivKey, s.alicePubX, s.alicePubY);
    uint256 sharedSecretAlice = Secp256k1.ecdh(s.alicePrivKey, s.bobPubX, s.bobPubY);

    assertEq(sharedSecretBob, sharedSecretAlice, "ECDH shared secrets must match");
    assertGt(sharedSecretBob, 0, "Shared secret should be non-zero");

    // Encrypted communication
    bytes memory plaintext = "Hello Alice! This is a secret message from Bob via DID keyAgreement ECDH.";

    bytes32 bobKey = SimpleEncryption.deriveKey(sharedSecretBob);
    bytes memory ciphertext = SimpleEncryption.xorCipher(plaintext, bobKey);

    assertTrue(keccak256(ciphertext) != keccak256(plaintext), "Ciphertext should differ from plaintext");

    bytes32 aliceKey = SimpleEncryption.deriveKey(sharedSecretAlice);
    bytes memory decrypted = SimpleEncryption.xorCipher(ciphertext, aliceKey);

    assertEq(keccak256(decrypted), keccak256(plaintext), "Decrypted message should match original plaintext");
  }

  // =========================================================================
  // EC MATH VALIDATION
  // =========================================================================

  function test_Secp256k1_ECMul_Should_MatchFoundryWallet_When_MultiplyingGenerator() public {
    // Test with multiple different private keys
    uint256[3] memory privKeys = [uint256(0xA11CE), uint256(0xB0B), uint256(0xDEAD)];

    for (uint256 i = 0; i < privKeys.length; i++) {
      Vm.Wallet memory wallet = vm.createWallet(privKeys[i]);
      (uint256 derivedX, uint256 derivedY) = Secp256k1.ecMul(privKeys[i], Secp256k1.GX, Secp256k1.GY);

      assertEq(derivedX, wallet.publicKeyX, "EC mul X mismatch");
      assertEq(derivedY, wallet.publicKeyY, "EC mul Y mismatch");
    }
  }

  // =========================================================================
  // COMPRESS/DECOMPRESS ROUND-TRIP
  // =========================================================================

  function test_Secp256k1_CompressDecompress_Should_RoundTrip_When_ValidPublicKey() public {
    // Generate a real key pair via Foundry
    Vm.Wallet memory wallet = vm.createWallet(0xCAFE);

    // Compress
    bytes memory compressed = Secp256k1.compressPublicKey(wallet.publicKeyX, wallet.publicKeyY);
    assertEq(compressed.length, 33, "Compressed key should be 33 bytes");

    // Verify prefix
    uint8 prefix = uint8(compressed[0]);
    assertTrue(prefix == 0x02 || prefix == 0x03, "Prefix should be 0x02 or 0x03");

    // Decompress
    (uint256 recoveredX, uint256 recoveredY) = Secp256k1.decompressPublicKey(compressed);

    assertEq(recoveredX, wallet.publicKeyX, "Round-trip X mismatch");
    assertEq(recoveredY, wallet.publicKeyY, "Round-trip Y mismatch");
  }
}
