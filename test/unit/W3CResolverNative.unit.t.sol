// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { CreateVmCommand } from "@src/interfaces/IDidManagerNative.sol";
import { W3CDidDocument, W3CVerificationMethod, W3CService, W3CDidInput } from "@src/interfaces/IW3CResolver.sol";
import { W3CResolverNative } from "@src/W3CResolverNative.sol";
import { DidInputRequired } from "@src/W3CResolverUtils.sol";
import { DEFAULT_VM_ID_NATIVE } from "@src/interfaces/IVMStorageNative.sol";
import { Vm } from "forge-std/Vm.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title W3CResolverNativeUnitTest
 * @notice Unit tests for W3CResolverNative contract
 * @dev Tests resolution-time derivation of W3C fields from native VM storage
 */
contract W3CResolverNativeUnitTest is TestBaseNative {
  using DidTestHelpersNative for *;

  // Test users
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;

  function setUp() public {
    _deployDidManagerNative();

    address[] memory users = new address[](2);
    string[] memory labels = new string[](2);
    users[0] = user1;
    labels[0] = "user1";
    users[1] = user2;
    labels[1] = "user2";
    _setupUsers(users, labels);
  }

  // =========================================================================
  // RESOLVE TESTS
  // =========================================================================

  function test_Resolve_Should_ReturnValidDidDocument_When_BasicDidExists() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Verify context
    assertEq(doc.context.length, 1);
    assertEq(doc.context[0], "https://www.w3.org/ns/did/v1");

    // Verify DID string starts with "did:"
    assertTrue(bytes(doc.id).length > 4);

    // Verify expiration
    assertGt(doc.expiration, 0);
  }

  function test_Resolve_Should_HandleDidWithDefaultVm_When_NoAdditionalVmsOrServicesExist() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Should have exactly 1 VM
    assertEq(doc.verificationMethod.length, 1);

    // VM should have derived type
    assertEq(doc.verificationMethod[0].type_, "EcdsaSecp256k1VerificationKey2019");

    // VM should have empty publicKeyMultibase (native VMs don't store it)
    assertEq(bytes(doc.verificationMethod[0].publicKeyMultibase).length, 0);

    // VM should have derived blockchainAccountId (CAIP-10)
    assertTrue(bytes(doc.verificationMethod[0].blockchainAccountId).length > 0);

    // VM should have ethereumAddress
    assertEq(doc.verificationMethod[0].ethereumAddress, Strings.toHexString(user1));

    // Should have authentication relationship
    assertEq(doc.authentication.length, 1);

    // Should have no services
    assertEq(doc.service.length, 0);
  }

  function test_Resolve_Should_DeriveBlockchainAccountId_When_EthereumAddressPresent() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Verify CAIP-10 format: "eip155:{chainId}:{address}"
    string memory expectedPrefix = string(abi.encodePacked("eip155:", Strings.toString(block.chainid), ":"));
    string memory actualAccountId = doc.verificationMethod[0].blockchainAccountId;

    // Check that it starts with "eip155:"
    bytes memory actualBytes = bytes(actualAccountId);
    bytes memory prefixBytes = bytes(expectedPrefix);
    for (uint256 i = 0; i < prefixBytes.length; i++) {
      assertEq(actualBytes[i], prefixBytes[i]);
    }
  }

  function test_Resolve_Should_IncludeServices_When_ServicesExist() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Add a service
    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    assertEq(doc.service.length, 1);
    assertEq(doc.service[0].type_.length, 1);
    assertEq(doc.service[0].type_[0], "LinkedDomains");
    assertEq(doc.service[0].serviceEndpoint.length, 1);
    assertEq(doc.service[0].serviceEndpoint[0], "https://bar.example.com");
  }

  function test_Resolve_Should_IncludeVerificationMethods_When_VmsExist() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    // Create additional VM
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_ASSERTION,
      publicKeyMultibase: "" // No keyAgreement
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();

    // Validate the new VM
    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    // Resolve
    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Should have 2 VMs
    assertEq(doc.verificationMethod.length, 2);

    // Both should have derived type
    assertEq(doc.verificationMethod[0].type_, "EcdsaSecp256k1VerificationKey2019");
    assertEq(doc.verificationMethod[1].type_, "EcdsaSecp256k1VerificationKey2019");

    // Should have correct relationships
    assertEq(doc.authentication.length, 2); // Both have authentication (0x01)
    assertEq(doc.assertionMethod.length, 1); // Only second VM has assertion (0x02)
  }

  function test_Resolve_Should_ExcludeExpiredMethods_When_IncludeExpiredFalse() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create additional VM (this internally stops/restarts prank for VM validation)
    DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_TEST_1);
    _stopPrank();

    // Re-prank as user1 to expire the second VM
    _startPrank(user1);
    didManagerNative.expireVm(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, Fixtures.VM_ID_TEST_1
    );
    _stopPrank();

    // Resolve without expired
    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Only the non-expired VM should be included
    assertEq(doc.verificationMethod.length, 1);
  }

  function test_Resolve_Should_IncludeExpiredMethods_When_IncludeExpiredTrue() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create additional VM (this internally stops/restarts prank for VM validation)
    DidTestHelpersNative.createDefaultVm(vm, didManagerNative, didResult.didInfo, Fixtures.VM_ID_TEST_1);
    _stopPrank();

    // Re-prank as user1 to expire the second VM
    _startPrank(user1);
    didManagerNative.expireVm(
      didResult.didInfo.methods, didResult.didInfo.id, DEFAULT_VM_ID_NATIVE, didResult.didInfo.id, Fixtures.VM_ID_TEST_1
    );
    _stopPrank();

    // Resolve with expired
    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), true
    );

    // Both VMs should be included
    assertEq(doc.verificationMethod.length, 2);
  }

  // =========================================================================
  // RESOLVE VM TESTS
  // =========================================================================

  function test_ResolveVm_Should_ReturnVerificationMethod_When_ValidVmIdProvided() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CVerificationMethod memory w3cVm = w3cResolverNative.resolveVm(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }),
      DEFAULT_VM_ID_NATIVE
    );

    assertEq(w3cVm.type_, "EcdsaSecp256k1VerificationKey2019");
    assertEq(w3cVm.ethereumAddress, Strings.toHexString(user1));
    assertGt(w3cVm.expiration, 0);
  }

  function test_ResolveVm_Should_ReturnEmptyVm_When_NonExistentVmIdProvided() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CVerificationMethod memory w3cVm = w3cResolverNative.resolveVm(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }),
      bytes32("nonexistent")
    );

    // Native VM with address(0) resolves to empty
    assertEq(w3cVm.ethereumAddress, Strings.toHexString(address(0)));
    assertEq(w3cVm.expiration, 0);
  }

  function test_RevertWhen_ResolveVm_WithEmptyDidInput() public {
    vm.expectRevert(DidInputRequired.selector);
    w3cResolverNative.resolveVm(
      W3CDidInput({ methods: bytes32(0), id: bytes32(0), fragment: bytes32(0) }), DEFAULT_VM_ID_NATIVE
    );
  }

  // =========================================================================
  // RESOLVE SERVICE TESTS
  // =========================================================================

  function test_ResolveService_Should_ReturnService_When_ValidServiceIdProvided() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
    _stopPrank();

    W3CService memory service = w3cResolverNative.resolveService(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }),
      Fixtures.DEFAULT_SERVICE_ID
    );

    assertEq(service.type_.length, 1);
    assertEq(service.type_[0], "LinkedDomains");
    assertEq(service.serviceEndpoint.length, 1);
    assertEq(service.serviceEndpoint[0], "https://bar.example.com");
  }

  function test_RevertWhen_ResolveService_WithEmptyDidInput() public {
    vm.expectRevert(DidInputRequired.selector);
    w3cResolverNative.resolveService(
      W3CDidInput({ methods: bytes32(0), id: bytes32(0), fragment: bytes32(0) }), Fixtures.DEFAULT_SERVICE_ID
    );
  }

  // =========================================================================
  // DID INPUT VALIDATION TESTS
  // =========================================================================

  function test_ValidateDidInput_Should_SetDefaultMethods_When_MethodsIsEmpty() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    // Call with empty methods - should use defaults
    W3CVerificationMethod memory w3cVm = w3cResolverNative.resolveVm(
      W3CDidInput({ methods: bytes32(0), id: didResult.didInfo.id, fragment: bytes32(0) }), DEFAULT_VM_ID_NATIVE
    );

    // Should succeed (methods defaulted) and return valid VM
    assertEq(w3cVm.type_, "EcdsaSecp256k1VerificationKey2019");
  }

  // =========================================================================
  // CONTROLLER RESOLUTION TESTS
  // =========================================================================

  // =========================================================================
  // RELATIONSHIP BITMASK TESTS (covers 0x04, 0x08, 0x10 branches)
  // =========================================================================

  function test_Resolve_Should_PopulateAllRelationships_When_VmHasAllRelationships() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    // Create a VM with ALL relationships (0x1F = auth + assertion + keyAgreement + capDelegation + capInvocation)
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_ALL,
      publicKeyMultibase: Fixtures.TEST_SECP256K1_MULTIBASE // Required for keyAgreement (0x04)
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();

    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Custom VM has auth (0x01), VM_ID_TEST_1 has all (0x1F)
    assertEq(doc.authentication.length, 2); // Both have 0x01
    assertEq(doc.assertionMethod.length, 1); // Only TEST_1 has 0x02
    assertEq(doc.keyAgreement.length, 1); // Only TEST_1 has 0x04
    assertEq(doc.capabilityDelegation.length, 1); // Only TEST_1 has 0x08
    assertEq(doc.capabilityInvocation.length, 1); // Only TEST_1 has 0x10

    // Verify publicKeyMultibase appears in resolved document for keyAgreement VM
    assertEq(doc.verificationMethod[1].publicKeyMultibase, string(Fixtures.TEST_SECP256K1_MULTIBASE));
  }

  // =========================================================================
  // INDIVIDUAL RELATIONSHIP TESTS
  // =========================================================================

  function test_Resolve_Should_PopulateKeyAgreementArray_When_VmHas0x04Flag() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    // Create VM with keyAgreement (0x04)
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT, // 0x04
      publicKeyMultibase: Fixtures.TEST_SECP256K1_MULTIBASE // Required for keyAgreement
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();

    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Custom VM has auth (0x01), VM_ID_TEST_1 has keyAgreement (0x04)
    assertEq(doc.authentication.length, 1); // Only custom VM
    assertEq(doc.assertionMethod.length, 0);
    assertEq(doc.keyAgreement.length, 1); // Only TEST_1
    assertEq(doc.verificationMethod.length, 2);

    // Verify publicKeyMultibase appears in resolved document for keyAgreement VM
    assertEq(doc.verificationMethod[1].publicKeyMultibase, string(Fixtures.TEST_SECP256K1_MULTIBASE));
  }

  // =========================================================================
  // EXPIRATION CONVERSION TESTS
  // =========================================================================

  function test_Resolve_Should_ConvertExpirationToMilliseconds_When_Resolving() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // DID expiration should be in milliseconds (seconds * 1000)
    uint256 rawExpiration = didManagerNative.getExpiration(didResult.didInfo.methods, didResult.didInfo.id, bytes32(0));
    assertEq(doc.expiration, rawExpiration * 1000);

    // VM expiration should also be in milliseconds and in the future
    assertGt(doc.verificationMethod[0].expiration, block.timestamp * 1000);
  }

  // =========================================================================
  // CAIP-10 CHAIN ID TESTS
  // =========================================================================

  function test_Resolve_Should_UseBlockChainId_When_ConstructingBlockchainAccountId() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // CAIP-10 format: "eip155:{chainId}:{address}"
    string memory chainIdStr = Strings.toString(block.chainid);
    string memory expectedPrefix = string(abi.encodePacked("eip155:", chainIdStr, ":"));
    string memory accountId = doc.verificationMethod[0].blockchainAccountId;

    // Verify prefix matches expected chain ID
    bytes memory actual = bytes(accountId);
    bytes memory prefix = bytes(expectedPrefix);
    assertTrue(actual.length > prefix.length, "Account ID should be longer than prefix");
    for (uint256 i = 0; i < prefix.length; i++) {
      assertEq(actual[i], prefix[i], "CAIP-10 prefix mismatch");
    }
  }

  // =========================================================================
  // _bytesToHexString TESTS
  // =========================================================================

  function test_BytesToHexString_Should_ConvertCorrectly_When_ValidInputProvided() public view {
    W3CResolverNative resolver = W3CResolverNative(address(w3cResolverNative));
    bytes memory input = new bytes(2);
    input[0] = 0xAB;
    input[1] = 0xCD;
    string memory result = resolver._bytesToHexString(input);
    assertEq(result, "abcd");
  }

  function test_BytesToHexString_Should_ReturnEmpty_When_EmptyInputProvided() public view {
    W3CResolverNative resolver = W3CResolverNative(address(w3cResolverNative));
    bytes memory input = new bytes(0);
    string memory result = resolver._bytesToHexString(input);
    assertEq(bytes(result).length, 0);
  }

  // =========================================================================
  // CONTROLLER RESOLUTION TESTS
  // =========================================================================

  function test_Resolve_Should_IncludeControllers_When_ControllersExist() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    DidTestHelpersNative.CreateDidResult memory controllerDid = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );

    didManagerNative.updateController(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      controllerDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    assertEq(doc.controller.length, 1);
    assertTrue(bytes(doc.controller[0]).length > 0);
  }

  // =========================================================================
  // MULTI-VALUE SERVICE TESTS (covers _parsePackedStrings delimiter branches)
  // =========================================================================

  function test_Resolve_Should_ParseMultipleServiceTypes_When_DelimiterPackedValues() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Create a service with multiple types and endpoints (packed with \x00 delimiter)
    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.SERVICE_TYPE_MULTIPLE, // "LinkedDomains\x00DIDCommMessaging"
      Fixtures.SERVICE_ENDPOINT_MULTIPLE // "https://primary.example.com\x00https://backup.example.com"
    );
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    assertEq(doc.service.length, 1);
    assertEq(doc.service[0].type_.length, 2);
    assertEq(doc.service[0].type_[0], "LinkedDomains");
    assertEq(doc.service[0].type_[1], "DIDCommMessaging");
    assertEq(doc.service[0].serviceEndpoint.length, 2);
    assertEq(doc.service[0].serviceEndpoint[0], "https://primary.example.com");
    assertEq(doc.service[0].serviceEndpoint[1], "https://backup.example.com");
  }

  function test_ResolveService_Should_ParseMultipleTypes_When_DelimiterPackedValues() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.SERVICE_TYPE_MULTIPLE,
      Fixtures.SERVICE_ENDPOINT_MULTIPLE
    );
    _stopPrank();

    W3CService memory service = w3cResolverNative.resolveService(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }),
      Fixtures.DEFAULT_SERVICE_ID
    );

    assertEq(service.type_.length, 2);
    assertEq(service.serviceEndpoint.length, 2);
  }

  function test_Resolve_Should_TrimTrailingEmpty_When_ServiceTypeHasTrailingDelimiter() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Service type with trailing delimiter: "LinkedDomains\x00"
    bytes memory typeWithTrailing = abi.encodePacked("LinkedDomains", bytes1(0x00));
    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      typeWithTrailing,
      Fixtures.defaultServiceEndpoint()
    );
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Trailing empty should be trimmed
    assertEq(doc.service[0].type_.length, 1);
    assertEq(doc.service[0].type_[0], "LinkedDomains");
  }

  function test_Resolve_Should_ReturnEmptyArray_When_ServiceTypeIsOnlyDelimiter() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);

    // Service type is just a delimiter: "\x00" → should parse to empty array
    bytes memory delimiterOnly = abi.encodePacked(bytes1(0x00));
    didManagerNative.updateService(
      didResult.didInfo.methods,
      didResult.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      didResult.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      delimiterOnly,
      Fixtures.defaultServiceEndpoint()
    );
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Only-delimiter input should return empty array (all strings empty → trimmed to 0)
    assertEq(doc.service[0].type_.length, 0);
  }

  // =========================================================================
  // PUBLIC KEY MULTIBASE RESOLUTION TESTS
  // =========================================================================

  function test_Resolve_Should_ReturnEmptyPublicKeyMultibase_When_NonKeyAgreementVm() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // Default VM has only auth (0x01), no keyAgreement → publicKeyMultibase should be empty
    assertEq(bytes(doc.verificationMethod[0].publicKeyMultibase).length, 0);
  }

  function test_Resolve_Should_ReturnPublicKeyMultibase_When_KeyAgreementVm() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    // Create VM with auth + keyAgreement and publicKeyMultibase
    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_AUTH_AND_KEY_AGREEMENT,
      publicKeyMultibase: Fixtures.TEST_SECP256K1_MULTIBASE
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();

    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    W3CDidDocument memory doc = w3cResolverNative.resolve(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }), false
    );

    // First VM (custom) has auth only → empty publicKeyMultibase
    assertEq(bytes(doc.verificationMethod[0].publicKeyMultibase).length, 0);

    // Second VM (TEST_1) has keyAgreement → publicKeyMultibase should match stored value
    assertEq(doc.verificationMethod[1].publicKeyMultibase, string(Fixtures.TEST_SECP256K1_MULTIBASE));

    // Verify keyAgreement array is populated
    assertEq(doc.keyAgreement.length, 1);
  }

  function test_ResolveVm_Should_ReturnPublicKeyMultibase_When_KeyAgreementVm() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory didResult = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );

    CreateVmCommand memory command = CreateVmCommand({
      methods: didResult.didInfo.methods,
      senderId: didResult.didInfo.id,
      senderVmId: Fixtures.VM_ID_CUSTOM,
      targetId: didResult.didInfo.id,
      vmId: Fixtures.VM_ID_TEST_1,
      ethereumAddress: user2,
      relationships: Fixtures.VM_RELATIONSHIPS_KEY_AGREEMENT,
      publicKeyMultibase: Fixtures.TEST_ED25519_MULTIBASE
    });

    vm.recordLogs();
    didManagerNative.createVm(command);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();

    _startPrank(user2);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();

    // Resolve single VM
    W3CVerificationMethod memory w3cVm = w3cResolverNative.resolveVm(
      W3CDidInput({ methods: didResult.didInfo.methods, id: didResult.didInfo.id, fragment: bytes32(0) }),
      Fixtures.VM_ID_TEST_1
    );

    assertEq(w3cVm.publicKeyMultibase, string(Fixtures.TEST_ED25519_MULTIBASE));
    assertEq(w3cVm.type_, "EcdsaSecp256k1VerificationKey2019");
  }
}
