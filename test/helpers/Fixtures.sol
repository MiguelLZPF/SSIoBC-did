// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title Fixtures
 * @notice Test data fixtures and constants for consistent test data
 * @dev Provides standardized test values across all test files
 */
library Fixtures {
  // =========================================================================
  // DID-related constants
  // =========================================================================

  // DID Methods
  bytes10 internal constant EMPTY_DID_METHOD = bytes10(0);
  bytes32 internal constant EMPTY_DID_METHODS = bytes32(0);
  bytes10 internal constant DEFAULT_DID_METHOD0 = bytes10("lzpf");
  bytes10 internal constant DEFAULT_DID_METHOD1 = bytes10("main");
  bytes10 internal constant DEFAULT_DID_METHOD2 = EMPTY_DID_METHOD;
  bytes10 internal constant CUSTOM_DID_METHOD_0 = bytes10("custom0;;;");
  bytes10 internal constant CUSTOM_DID_METHOD_1 = bytes10("custom1;;;");
  bytes10 internal constant CUSTOM_DID_METHOD_2 = bytes10("custom2;;;");
  bytes32 internal constant CUSTOM_DID_METHODS = bytes32("custom0;;;custom1;;;custom2;;;");

  // DID IDs and Random values
  bytes32 internal constant EMPTY_DID_ID = bytes32(0);
  bytes32 internal constant EMPTY_RANDOM = bytes32(0);
  bytes32 internal constant DEFAULT_RANDOM_0 = bytes32("default-random");
  bytes32 internal constant DEFAULT_RANDOM_1 = bytes32("default-random-1");
  bytes32 internal constant DEFAULT_RANDOM_2 = bytes32("default-random-2");
  bytes32 internal constant DEFAULT_RANDOM_3 = bytes32("default-random-3");

  // =========================================================================
  // VM-related constants
  // =========================================================================

  // VM IDs
  bytes32 internal constant EMPTY_VM_ID = bytes32(0);
  bytes32 internal constant VM_ID_CUSTOM = bytes32("vm_custom");
  bytes32 internal constant VM_ID_CUSTOM_2 = bytes32("vm_custom_2");
  bytes32 internal constant VM_ID_TEST_1 = bytes32("vm-test-1");
  bytes32 internal constant VM_ID_TEST_2 = bytes32("vm-test-2");

  // VM Types
  function defaultVmType() internal pure returns (bytes32[2] memory) {
    return [bytes32("EcdsaSecp256k1VerificationKey20"), bytes32("19")];
  }

  function emptyVmType() internal pure returns (bytes32[2] memory) {
    return [bytes32(0), bytes32(0)];
  }

  // =========================================================================
  // VM Public Key constants (pre-encoded multibase format)
  // =========================================================================

  // Pre-encoded multibase strings (base58btc with 'z' prefix)
  // These are valid multibase-encoded public keys for testing purposes
  // Format: 'z' + base58btc(multicodec + rawPublicKey)

  // Test secp256k1 compressed public key multibase
  // Original raw: 0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798
  // Multicodec: 0xe701 (secp256k1-pub)
  bytes internal constant TEST_SECP256K1_MULTIBASE = "zQ3shokFTS3brHcDQrn82RUDfQ23n1FVsyBYbepBrn4Q8nyB1";

  // Test Ed25519 public key multibase
  // Original raw: 0xd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a
  // Multicodec: 0xed01 (ed25519-pub)
  bytes internal constant TEST_ED25519_MULTIBASE = "z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK";

  // Empty multibase for VMs that use ethereumAddress instead
  bytes internal constant EMPTY_PUBLIC_KEY_MULTIBASE = "";

  // VM Public Keys - returns pre-encoded multibase string
  function defaultVmPublicKeyMultibase() internal pure returns (bytes memory) {
    return TEST_SECP256K1_MULTIBASE;
  }

  function ed25519VmPublicKeyMultibase() internal pure returns (bytes memory) {
    return TEST_ED25519_MULTIBASE;
  }

  function emptyVmPublicKeyMultibase() internal pure returns (bytes memory) {
    return EMPTY_PUBLIC_KEY_MULTIBASE;
  }

  // =========================================================================
  // VM Blockchain Account ID (CAIP-10 format string)
  // =========================================================================

  // CAIP-10 format: chain_id:account_address
  // Example: eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb
  bytes internal constant DEFAULT_CAIP10_ACCOUNT_ID = "eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb";

  function defaultVmBlockchainAccountId() internal pure returns (bytes memory) {
    return DEFAULT_CAIP10_ACCOUNT_ID;
  }

  function emptyVmBlockchainAccountId() internal pure returns (bytes memory) {
    return "";
  }

  // VM Ethereum Addresses
  address internal constant EMPTY_VM_ETHEREUM_ADDRESS = address(0);
  address internal constant DEFAULT_VM_ETHEREUM_ADDRESS = address(0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb);

  // VM Expiration
  uint256 internal constant EMPTY_VM_EXPIRATION = 0; // Means never validated (invalid)
  uint256 internal constant VALID_VM_EXPIRATION = type(uint256).max; // Use max value for tests that need a valid VM

  // VM Relationships
  bytes1 internal constant VM_RELATIONSHIPS_NONE = bytes1(0x00);
  bytes1 internal constant VM_RELATIONSHIPS_AUTHENTICATION = bytes1(0x01);
  bytes1 internal constant VM_RELATIONSHIPS_ASSERTION_METHOD = bytes1(0x02);
  bytes1 internal constant VM_RELATIONSHIPS_KEY_AGREEMENT = bytes1(0x04);
  bytes1 internal constant VM_RELATIONSHIPS_CAPABILITY_INVOCATION = bytes1(0x08);
  bytes1 internal constant VM_RELATIONSHIPS_CAPABILITY_DELEGATION = bytes1(0x10);
  bytes1 internal constant VM_RELATIONSHIPS_ALL = bytes1(0x1F);
  bytes1 internal constant DEFAULT_VM_RELATIONSHIPS = VM_RELATIONSHIPS_AUTHENTICATION;

  // Combined relationships for testing
  bytes1 internal constant VM_RELATIONSHIPS_AUTH_AND_DELEGATION = bytes1(0x11); // 0x01 | 0x10
  bytes1 internal constant VM_RELATIONSHIPS_AUTH_AND_ASSERTION = bytes1(0x03); // 0x01 | 0x02
  bytes1 internal constant VM_RELATIONSHIPS_AUTH_AND_KEY_AGREEMENT = bytes1(0x05); // 0x01 | 0x04
  bytes1 internal constant VM_RELATIONSHIPS_INVALID = bytes1(0x20); // > 0x1F (invalid)

  // =========================================================================
  // Time-related constants
  // =========================================================================

  // Time durations in seconds
  uint256 internal constant SECONDS_IN_MINUTE = 60;
  uint256 internal constant SECONDS_IN_HOUR = 3600;
  uint256 internal constant SECONDS_IN_DAY = 86400;
  uint256 internal constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
  uint256 internal constant DID_MAX_EXPIRATION_PERIOD = 4 * SECONDS_IN_YEAR; // 4 years
  uint256 internal constant VM_DEFAULT_EXPIRATION_PERIOD = SECONDS_IN_YEAR; // 1 year

  // Test time offsets
  uint256 internal constant TEST_TIME_ADVANCE_SHORT = 100; // seconds
  uint256 internal constant TEST_TIME_ADVANCE_MEDIUM = 3600; // 1 hour
  uint256 internal constant TEST_TIME_ADVANCE_LONG = 2 * SECONDS_IN_MINUTE; // 2 minutes
  uint256 internal constant TEST_VM_EXPIRATION_OFFSET = SECONDS_IN_MINUTE; // 1 minute
  uint256 internal constant TEST_EXPIRATION_BUFFER = SECONDS_IN_DAY; // 1 day buffer for assertions

  // Time warp constants for testing
  uint256 internal constant WARP_TO_EXPIRE_DID = 5 * SECONDS_IN_YEAR; // 5 years to force DID expiration
  uint256 internal constant WARP_TO_EXPIRE_VM = 2 * SECONDS_IN_YEAR; // 2 years for VM expiration

  // =========================================================================
  // Test scenario constants
  // =========================================================================

  // Limits for stress testing
  uint256 internal constant MAX_REASONABLE_VM_COUNT = 100;
  uint256 internal constant STRESS_TEST_VM_LIMIT = 20;
  uint256 internal constant STRESS_TEST_SERVICE_LIMIT = 15;
  uint256 internal constant STRESS_TEST_CONTROLLER_LIMIT = 3;
  uint8 internal constant INVALID_CONTROLLER_POSITION = 255;

  // Gas testing constants
  uint256 internal constant TEST_ETHER_AMOUNT = 100 ether;
  uint8 internal constant INVALID_ARRAY_POSITION = 99; // For testing invalid array access

  // =========================================================================
  // Service-related constants (v1.1 optimized - dynamic bytes)
  // =========================================================================

  // Service IDs
  bytes32 internal constant DEFAULT_SERVICE_ID = bytes32("linked-domain");
  bytes32 internal constant SERVICE_ID_TEST_1 = bytes32("test-service-1");
  bytes32 internal constant SERVICE_ID_TEST_2 = bytes32("test-service-2");

  // Service Types (packed bytes with '\x00' delimiter)
  bytes internal constant DEFAULT_SERVICE_TYPE = "LinkedDomains";
  bytes internal constant EMPTY_SERVICE_TYPE = "";

  // Multiple types packed with delimiter
  bytes internal constant SERVICE_TYPE_MULTIPLE = "LinkedDomains\x00DIDCommMessaging";
  bytes internal constant SERVICE_TYPE_SMART_CONTRACT = "VerifiableCredentialService\x00SmartContractEndpoint";

  // Service Endpoints (packed bytes with '\x00' delimiter)
  bytes internal constant DEFAULT_SERVICE_ENDPOINT = "https://bar.example.com";
  bytes internal constant EMPTY_SERVICE_ENDPOINT = "";

  // Multiple endpoints packed with delimiter
  bytes internal constant SERVICE_ENDPOINT_MULTIPLE = "https://primary.example.com\x00https://backup.example.com";
  bytes internal constant SERVICE_ENDPOINT_SMART_CONTRACT = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

  // Service fixture functions for backward compatibility
  function defaultServiceType() internal pure returns (bytes memory) {
    return DEFAULT_SERVICE_TYPE;
  }

  function emptyServiceType() internal pure returns (bytes memory) {
    return EMPTY_SERVICE_TYPE;
  }

  function defaultServiceEndpoint() internal pure returns (bytes memory) {
    return DEFAULT_SERVICE_ENDPOINT;
  }

  function emptyServiceEndpoint() internal pure returns (bytes memory) {
    return EMPTY_SERVICE_ENDPOINT;
  }

  function serviceTypeSmartContract() internal pure returns (bytes memory) {
    return SERVICE_TYPE_SMART_CONTRACT;
  }

  function serviceEndpointSmartContract() internal pure returns (bytes memory) {
    return SERVICE_ENDPOINT_SMART_CONTRACT;
  }

  // =========================================================================
  // Test Users
  // =========================================================================

  address internal constant TEST_USER_ADMIN = address(0x1);
  address internal constant TEST_USER_1 = address(0x10);
  address internal constant TEST_USER_2 = address(0x11);
  address internal constant TEST_USER_3 = address(0x12);
  address internal constant TEST_USER_4 = address(0x13);

  // =========================================================================
  // Utility Functions
  // =========================================================================

  /**
   * @notice Calculates DID hash from methods and random
   * @param methods The DID methods
   * @param random The random value
   * @return The calculated hash
   */
  function calculateDidHash(bytes32 methods, bytes32 random) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(methods, random));
  }

  /**
   * @notice Gets current timestamp plus specified seconds
   * @param additionalSeconds Seconds to add to current timestamp
   * @return Future timestamp
   */
  function futureTimestamp(uint256 additionalSeconds) internal view returns (uint256) {
    return block.timestamp + additionalSeconds;
  }
}
