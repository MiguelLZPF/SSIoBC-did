// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { SERVICE_MAX_LENGTH_LIST, SERVICE_MAX_LENGTH } from "@src/ServiceStorage.sol";

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

  // VM Public Keys
  function defaultVmPublicKey() internal pure returns (bytes32[16] memory) {
    bytes32[16] memory result;
    result[0] = bytes32("FD756c746962617365206973206177");
    result[1] = bytes32("65736F6d6521205C6f2F");
    result[2] = bytes32("65736F6d6521205C6f2F");
    return result;
  }

  function emptyVmPublicKey() internal pure returns (bytes32[16] memory) {
    return [
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0),
      bytes32(0)
    ];
  }

  // VM Blockchain Account ID
  function defaultVmBlockchainAccountId() internal pure returns (bytes32[5] memory) {
    bytes32[5] memory result;
    result[0] = bytes32("eid155:1:0xab16a96d359ec26a11e2c");
    result[1] = bytes32("2b3d8f8b8942d5bfcdb");
    return result;
  }

  function emptyVmBlockchainAccountId() internal pure returns (bytes32[5] memory) {
    return [bytes32(0), bytes32(0), bytes32(0), bytes32(0), bytes32(0)];
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
  // Service-related constants
  // =========================================================================

  // Service IDs
  bytes32 internal constant DEFAULT_SERVICE_ID = bytes32("linked-domain");
  bytes32 internal constant SERVICE_ID_TEST_1 = bytes32("test-service-1");
  bytes32 internal constant SERVICE_ID_TEST_2 = bytes32("test-service-2");

  // Service Types
  function defaultServiceType() internal pure returns (bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory) {
    bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory result;
    result[0][0] = bytes32("LinkedDomains");
    return result;
  }

  function serviceTypeSmartContract()
    internal
    pure
    returns (bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory)
  {
    bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory result;
    result[0][0] = bytes32("VerifiableCredentialService");
    result[1][0] = bytes32("SmartContractEndpoint");
    return result;
  }

  // Service Endpoints
  function defaultServiceEndpoint()
    internal
    pure
    returns (bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory)
  {
    bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory result;
    result[0][0] = bytes32("https://bar.example.com");
    return result;
  }

  function serviceEndpointSmartContract()
    internal
    pure
    returns (bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory)
  {
    bytes32[SERVICE_MAX_LENGTH_LIST][SERVICE_MAX_LENGTH] memory result;
    result[0][0] = bytes32("0xe7f1725E7734CE288F8367e1Bb143E");
    result[0][1] = bytes32("90bb3F0512");
    return result;
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
