// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { W3CResolver } from "@src/W3CResolver.sol";
import { W3CResolverNative } from "@src/W3CResolverNative.sol";
import { W3CDidInput, W3CDidDocument } from "@types/W3CTypes.sol";
import { DEFAULT_DID_METHODS } from "@types/DidTypes.sol";

/// @title DidAbnf
/// @notice Asserts a string satisfies the W3C DID Core v1.0 section 3.1 ABNF:
///
///   did                = "did:" method-name ":" method-specific-id
///   method-name        = 1*method-char
///   method-char        = %x61-7A / DIGIT
///   method-specific-id = *( *idchar ":" ) 1*idchar
///   idchar             = ALPHA / DIGIT / "." / "-" / "_" / pct-encoded
///
/// A fragment ("#...") may follow; it is a DID URL component and is checked only for being
/// non-empty. This checker exists because the filler characters that make the internal
/// `bytes32 methods` encoding readable are NOT legal DID characters, and a regression there
/// is invisible unless something asserts the emitted syntax.
abstract contract DidAbnf {
  function _isMethodChar(bytes1 c) private pure returns (bool) {
    return (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39); // a-z / 0-9
  }

  function _isIdChar(bytes1 c) private pure returns (bool) {
    return (c >= 0x61 && c <= 0x7A) // a-z
      || (c >= 0x41 && c <= 0x5A) // A-Z
      || (c >= 0x30 && c <= 0x39) // 0-9
      || c == 0x2E // .
      || c == 0x2D // -
      || c == 0x5F // _
      || c == 0x25; // % (pct-encoded)
  }

  /// @dev Reverts with a descriptive reason when `did` violates the ABNF.
  function _assertConformantDid(string memory did) internal pure {
    bytes memory b = bytes(did);
    require(b.length > 4, "did: too short");
    require(b[0] == "d" && b[1] == "i" && b[2] == "d" && b[3] == ":", "did: missing 'did:' prefix");

    // method-name: 1*method-char, terminated by ':'
    uint256 i = 4;
    uint256 methodStart = i;
    while (i < b.length && b[i] != ":") {
      require(_isMethodChar(b[i]), "did: illegal char in method-name");
      i++;
    }
    require(i > methodStart, "did: empty method-name");
    require(i < b.length, "did: missing ':' after method-name");
    i++; // consume ':'

    // method-specific-id, up to an optional '#fragment'
    uint256 idStart = i;
    uint256 idChars = 0;
    while (i < b.length && b[i] != "#") {
      if (b[i] != ":") {
        require(_isIdChar(b[i]), "did: illegal char in method-specific-id");
        idChars++;
      }
      i++;
    }
    require(i > idStart, "did: empty method-specific-id");
    require(idChars > 0, "did: method-specific-id has no idchar");
    require(b[b.length - 1] != ":", "did: trailing ':'");

    if (i < b.length) {
      require(i + 1 < b.length, "did: empty fragment after '#'");
    }
  }

  /// @dev Lowercase hex of a bytes32, matching the resolver's id rendering.
  function _hex(bytes32 value) internal pure returns (string memory) {
    bytes16 digits = "0123456789abcdef";
    bytes memory out = new bytes(64);
    for (uint256 i = 0; i < 32; i++) {
      out[i * 2] = digits[uint8(value[i]) >> 4];
      out[i * 2 + 1] = digits[uint8(value[i]) & 0x0F];
    }
    return string(out);
  }
}

// =========================================================================
// Full W3C Variant
// =========================================================================

contract DidStringConformanceUnitTest is TestBase, DidAbnf {
  W3CResolver internal resolver;
  address internal user1 = address(0xA11CE);

  function setUp() public {
    _deployDidManager();
    resolver = new W3CResolver(didManager);
    _setupUser(user1, "User1");
  }

  function _create(bytes32 methods, bytes32 random) internal returns (bytes32 id) {
    _startPrank(user1);
    didManager.createDid(methods, random, bytes32(0));
    _stopPrank();
    bytes32 effective = methods == bytes32(0) ? DEFAULT_DID_METHODS : methods;
    return keccak256(abi.encodePacked(effective, random, user1, block.prevrandao));
  }

  function _resolve(bytes32 methods, bytes32 id) internal view returns (string memory) {
    W3CDidDocument memory doc = resolver.resolve(W3CDidInput({ methods: methods, id: id, fragment: bytes32(0) }), false);
    return doc.id;
  }

  /// @notice The default methods constant pads with ";", which is not a legal DID character.
  function test_DidString_Should_BeConformant_When_DefaultMethodsUsed() public {
    bytes32 id = _create(DEFAULT_DID_METHODS, bytes32("rand-default"));
    string memory did = _resolve(DEFAULT_DID_METHODS, id);
    _assertConformantDid(did);
    assertEq(did, string(abi.encodePacked("did:lzpf:main:", _hex(id))), "Default methods render as did:lzpf:main:<id>");
  }

  /// @notice Passing methods = 0 falls back to DEFAULT_DID_METHODS inside the contract.
  function test_DidString_Should_BeConformant_When_MethodsOmitted() public {
    bytes32 id = _create(bytes32(0), bytes32("rand-omitted"));
    _assertConformantDid(_resolve(bytes32(0), id));
  }

  /// @notice Zero-padded methods (no ";" filler) must render identically.
  function test_DidString_Should_BeConformant_When_ZeroPaddedMethods() public {
    bytes32 methods = bytes32(bytes10("lzpf")) | (bytes32(bytes10("main")) >> 80);
    bytes32 id = _create(methods, bytes32("rand-zero"));
    string memory did = _resolve(methods, id);
    _assertConformantDid(did);
    assertEq(did, string(abi.encodePacked("did:lzpf:main:", _hex(id))), "Zero padding renders the same");
  }

  /// @notice All three segments populated renders four colon-separated parts.
  function test_DidString_Should_BeConformant_When_ThreeSegmentsPopulated() public {
    bytes32 methods = bytes32(bytes10("lzpf")) | (bytes32(bytes10("main")) >> 80) | (bytes32(bytes10("testnet")) >> 160);
    bytes32 id = _create(methods, bytes32("rand-three"));
    string memory did = _resolve(methods, id);
    _assertConformantDid(did);
    assertEq(did, string(abi.encodePacked("did:lzpf:main:testnet:", _hex(id))), "Three segments all render");
  }

  /// @notice A single-segment method renders as did:<name>:<id> with no empty parts.
  function test_DidString_Should_BeConformant_When_SingleSegment() public {
    bytes32 methods = bytes32(bytes10("lzpf"));
    bytes32 id = _create(methods, bytes32("rand-single"));
    string memory did = _resolve(methods, id);
    _assertConformantDid(did);
    assertEq(did, string(abi.encodePacked("did:lzpf:", _hex(id))), "Single segment renders as did:lzpf:<id>");
  }

  /// @notice The ";" filler is an internal encoding detail and must never be emitted.
  function test_DidString_Should_NotContainFiller_When_DefaultMethodsUsed() public {
    bytes32 id = _create(DEFAULT_DID_METHODS, bytes32("rand-filler"));
    bytes memory did = bytes(_resolve(DEFAULT_DID_METHODS, id));
    for (uint256 i = 0; i < did.length; i++) {
      assertTrue(did[i] != 0x3B, "DID string must not contain ';'");
      assertTrue(did[i] != 0x00, "DID string must not contain a NUL byte");
    }
  }

  /// @notice The checker must reject the pre-fix output, otherwise it proves nothing.
  function test_AbnfChecker_Should_Reject_When_StringContainsFiller() public {
    vm.expectRevert(bytes("did: illegal char in method-name"));
    this.exposedAssertConformantDid("did:lzpf;;;;;;:main;;;;;;:;;;;;;;;;;:b3dd18c0");
  }

  /// @dev External wrapper so `vm.expectRevert` can observe the failure.
  function exposedAssertConformantDid(string calldata did) external pure {
    _assertConformantDid(did);
  }
}

// =========================================================================
// Ethereum-Native Variant
// =========================================================================

contract DidStringConformanceNativeUnitTest is TestBaseNative, DidAbnf {
  W3CResolverNative internal resolver;
  address internal user1 = address(0xA11CE);

  function setUp() public {
    _deployDidManagerNative();
    resolver = new W3CResolverNative(didManagerNative);
    _setupUser(user1, "User1");
  }

  function _create(bytes32 methods, bytes32 random) internal returns (bytes32 id) {
    _startPrank(user1);
    didManagerNative.createDid(methods, random, bytes32(0));
    _stopPrank();
    bytes32 effective = methods == bytes32(0) ? DEFAULT_DID_METHODS : methods;
    return keccak256(abi.encodePacked(effective, random, user1, block.prevrandao));
  }

  function _resolve(bytes32 methods, bytes32 id) internal view returns (string memory) {
    W3CDidDocument memory doc = resolver.resolve(W3CDidInput({ methods: methods, id: id, fragment: bytes32(0) }), false);
    return doc.id;
  }

  function test_Native_DidString_Should_BeConformant_When_DefaultMethodsUsed() public {
    bytes32 id = _create(DEFAULT_DID_METHODS, bytes32("rand-native"));
    string memory did = _resolve(DEFAULT_DID_METHODS, id);
    _assertConformantDid(did);
    assertEq(did, string(abi.encodePacked("did:lzpf:main:", _hex(id))), "Default methods render as did:lzpf:main:<id>");
  }

  function test_Native_DidString_Should_NotContainFiller() public {
    bytes32 id = _create(DEFAULT_DID_METHODS, bytes32("rand-native-2"));
    bytes memory did = bytes(_resolve(DEFAULT_DID_METHODS, id));
    for (uint256 i = 0; i < did.length; i++) {
      assertTrue(did[i] != 0x3B, "DID string must not contain ';'");
    }
  }

  function test_Native_DidString_Should_BeConformant_When_ThreeSegmentsPopulated() public {
    bytes32 methods = bytes32(bytes10("lzpf")) | (bytes32(bytes10("main")) >> 80) | (bytes32(bytes10("testnet")) >> 160);
    bytes32 id = _create(methods, bytes32("rand-native-3"));
    _assertConformantDid(_resolve(methods, id));
  }
}
