// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Vm } from "forge-std/Vm.sol";
import { TestBase } from "../helpers/TestBase.sol";
import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { DidCreateVmCommandNative as CreateVmCommandNative } from "@types/VmTypesNative.sol";
import { DEFAULT_VM_ID } from "@types/VmTypes.sol";
import { DEFAULT_VM_ID_NATIVE } from "@types/VmTypesNative.sol";
import { W3CResolverBase } from "@src/W3CResolverBase.sol";
import { HashUtils } from "@src/HashUtils.sol";
import { W3CDidDocument, W3CVerificationMethod, W3CService, W3CDidInput } from "@types/W3CTypes.sol";

/**
 * @title ResolverGoldenOutputUnitTest
 * @notice Pins resolver output byte-for-byte for the v1.7.0 gas pass. A change that alters any hash changed
 * observable behaviour.
 * @dev Each test builds a fixed fixture, calls the resolver and compares `keccak256(abi.encode(result))` with a
 * hard-coded constant. The timestamp is fixed so expirations are reproducible.
 *
 * Fixtures:
 *  - F1: 3 VMs covering all five relationship bits, 2 services (one with `0x00`-packed multi-values), 2 controllers.
 *  - F2: F1 after the middle VM is expired (the `includeExpired = false` filter shifts array indices).
 *  - F3: non-zero `didInput.fragment`, including one whose first byte is `0x00` (`trimBytes` returns empty).
 */
abstract contract ResolverGoldenFixtures {
  uint256 internal constant GOLDEN_TIMESTAMP = 1_700_000_000;
  // First byte is 0x00: trimBytes() yields an empty string for it.
  bytes32 internal constant VM_ID_LEADING_ZERO = bytes32(uint256(0x42));
  bytes32 internal constant FRAGMENT_PLAIN = bytes32("frag-1");
  bytes32 internal constant FRAGMENT_LEADING_ZERO = bytes32(uint256(0x07));

  function _hash(W3CDidDocument memory doc) internal pure returns (bytes32) {
    return keccak256(abi.encode(doc));
  }

  function _hash(W3CVerificationMethod memory vmOut) internal pure returns (bytes32) {
    return keccak256(abi.encode(vmOut));
  }

  function _hash(W3CService memory svc) internal pure returns (bytes32) {
    return keccak256(abi.encode(svc));
  }
}

contract ResolverGoldenOutputFullUnitTest is TestBase, ResolverGoldenFixtures {
  using DidTestHelpers for *;

  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;

  bytes32 private methods;
  bytes32 private didId;
  bytes32 private controllerBId;
  bytes32 private controllerCId;

  // Measured on the unmodified v1.6.0 sources (c8c1ebe).
  bytes32 private constant GOLDEN_F1_RESOLVE_FALSE = 0xb8e35989955c57f7e19361503e08396dcce25172c9e8bd738bb13cfd27896b72;
  bytes32 private constant GOLDEN_F1_RESOLVE_TRUE = 0xb8e35989955c57f7e19361503e08396dcce25172c9e8bd738bb13cfd27896b72;
  bytes32 private constant GOLDEN_F1_VMS = 0x833ce6ef731f12cf0c56ae3032d31c9e096de7386617d2e870778ce165d81bc4;
  bytes32 private constant GOLDEN_F1_SERVICES = 0x8f7fd16dbe7dbc18e27bcff2a431bf3775a91a0e789192ff8ff6b54ca4224565;
  bytes32 private constant GOLDEN_F2_RESOLVE_FALSE = 0x0856df126c3918628cd0372638c10df15fa8c8e97be006cf49fff3dfb99f0083;
  bytes32 private constant GOLDEN_F2_RESOLVE_TRUE = 0xf1aec7bbc01ce3e386ba63cd0ae183003fcb5845f64640761e36aeb151278183;
  bytes32 private constant GOLDEN_F3_PLAIN = 0x2110f996ce2bee512fe4cb106e22ea423abd4975beb024bf4bf5ef2fc7f9d8a1;
  bytes32 private constant GOLDEN_F3_LEADING_ZERO = 0xb4fb4337c43e6f396539a99f948eab76a496fdcb0b09c30e2133d9c20d5a8bdd;
  bytes32 private constant GOLDEN_F3_PLAIN_VM = 0x657253dffbf24415e9ba8e0ac8513512842046ff155cbecd67bb5e533155cb48;
  bytes32 private constant GOLDEN_F3_LEADING_ZERO_VM =
    0xdbdf6cb0856cca16dbd3c0866aa8cf1dc7a01f2ce7794aab33c610c86cb613ab;

  // F4 to F7 were added after review and measured on the original sources (5555ebd).
  bytes32 private constant GOLDEN_F4_UNVALIDATED_EXCLUDE =
    0xb3d188151ed38da4233bac41fb72fc1a9574c4fd4e81c99ef50495c25f24c6dc;
  bytes32 private constant GOLDEN_F4_UNVALIDATED_INCLUDE =
    0x4b4de9d043c011da2dddb60af4b0be0fe0d7f832f097dbb3c8d25ca9a8a3e890;
  bytes32 private constant GOLDEN_F5_BLOCKCHAIN_ACCOUNT =
    0x0dd6e9fb1b35a59cd8210a8364536c7081b1b9d24bb01cb9978863daeef80e94;
  bytes32 private constant GOLDEN_F6_METHODS_ONE_SEGMENT =
    0x0f068ab48298e856250c749f2e5487582b7db7532c2a35208501162facdceb1b;
  bytes32 private constant GOLDEN_F6_METHODS_THREE_SEGMENTS =
    0x23460a285e5f3176369ce206531953f8a10ed3a29ff4f008d9498c62243195df;
  bytes32 private constant GOLDEN_F7_RECREATED_INCLUDE =
    0xb98cbacc09f53bb5224b859ce62a3e2f0e5c28a7f10ebb2584f28ff36faf6a8d;
  bytes32 private constant GOLDEN_F7_RECREATED_EXCLUDE =
    0xb98cbacc09f53bb5224b859ce62a3e2f0e5c28a7f10ebb2584f28ff36faf6a8d;

  function setUp() public {
    vm.warp(GOLDEN_TIMESTAMP);
    _deployDidManager();
    _setupUser(user1, "user1");
    _setupUser(user2, "user2");
  }

  function _input(bytes32 fragment) private view returns (W3CDidInput memory) {
    return W3CDidInput({ methods: methods, id: didId, fragment: fragment });
  }

  function _createVm(bytes32 vmId, bytes1 relationships) private {
    didManager.createVm(
      CreateVmCommand({
        methods: methods,
        senderId: didId,
        senderVmId: DEFAULT_VM_ID,
        targetId: didId,
        vmId: vmId,
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.TEST_SECP256K1_MULTIBASE,
        blockchainAccountId: "",
        ethereumAddress: address(0),
        relationships: relationships,
        expiration: uint88(GOLDEN_TIMESTAMP + 365 days)
      })
    );
  }

  /// @dev Builds F1: default VM "vm-0" plus two VMs, two services, then two controllers.
  function _buildF1() private {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory created = DidTestHelpers.createDefaultDid(vm, didManager);
    methods = created.didInfo.methods;
    didId = created.didInfo.id;

    // Relationship bits across the three VMs: vm-0 = auth (0x01) from createDid,
    // custom = assertion + keyAgreement (0x06), leading-zero id = invocation + delegation + auth (0x19).
    _createVm(Fixtures.VM_ID_CUSTOM, 0x06);
    _createVm(VM_ID_LEADING_ZERO, 0x19);

    didManager.updateService(
      methods,
      didId,
      DEFAULT_VM_ID,
      didId,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.SERVICE_TYPE_MULTIPLE,
      Fixtures.SERVICE_ENDPOINT_MULTIPLE
    );
    didManager.updateService(
      methods,
      didId,
      DEFAULT_VM_ID,
      didId,
      Fixtures.SERVICE_ID_TEST_1,
      Fixtures.DEFAULT_SERVICE_TYPE,
      Fixtures.DEFAULT_SERVICE_ENDPOINT
    );

    // Controller B (with vmId) at position 0, set by the owner.
    controllerBId =
    DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0))
      .didInfo
      .id;
    controllerCId =
    DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0))
      .didInfo
      .id;
    didManager.updateController(methods, didId, DEFAULT_VM_ID, didId, controllerBId, DEFAULT_VM_ID, 0);
    // Controller C (no vmId) at position 1, set by controller B (the owner can no longer act once controllers exist).
    didManager.updateController(methods, controllerBId, DEFAULT_VM_ID, didId, controllerCId, bytes32(0), 1);
    _stopPrank();
  }

  /// @dev F2: expire the middle VM, acting as controller B.
  function _buildF2() private {
    _buildF1();
    _startPrank(user1);
    didManager.expireVm(methods, controllerBId, DEFAULT_VM_ID, didId, Fixtures.VM_ID_CUSTOM);
    _stopPrank();
  }

  function test_Golden_F1_Resolve_ExcludeExpired() public {
    _buildF1();
    assertEq(_hash(w3cResolver.resolve(_input(bytes32(0)), false)), GOLDEN_F1_RESOLVE_FALSE);
  }

  function test_Golden_F1_Resolve_IncludeExpired() public {
    _buildF1();
    assertEq(_hash(w3cResolver.resolve(_input(bytes32(0)), true)), GOLDEN_F1_RESOLVE_TRUE);
  }

  function test_Golden_F1_ResolveVm_EachVm() public {
    _buildF1();
    bytes32 acc;
    bytes32[3] memory ids = [DEFAULT_VM_ID, Fixtures.VM_ID_CUSTOM, VM_ID_LEADING_ZERO];
    for (uint256 i = 0; i < ids.length; i++) {
      acc = keccak256(abi.encode(acc, _hash(w3cResolver.resolveVm(_input(bytes32(0)), ids[i]))));
    }
    assertEq(acc, GOLDEN_F1_VMS);
  }

  function test_Golden_F1_ResolveService_EachService() public {
    _buildF1();
    bytes32 acc;
    bytes32[2] memory ids = [Fixtures.DEFAULT_SERVICE_ID, Fixtures.SERVICE_ID_TEST_1];
    for (uint256 i = 0; i < ids.length; i++) {
      acc = keccak256(abi.encode(acc, _hash(w3cResolver.resolveService(_input(bytes32(0)), ids[i]))));
    }
    assertEq(acc, GOLDEN_F1_SERVICES);
  }

  function test_Golden_F2_Resolve_ExcludeExpired() public {
    _buildF2();
    W3CDidDocument memory doc = w3cResolver.resolve(_input(bytes32(0)), false);
    assertEq(doc.verificationMethod.length, 2); // sanity: the filter really dropped the middle VM
    assertEq(_hash(doc), GOLDEN_F2_RESOLVE_FALSE);
  }

  function test_Golden_F2_Resolve_IncludeExpired() public {
    _buildF2();
    W3CDidDocument memory doc = w3cResolver.resolve(_input(bytes32(0)), true);
    assertEq(doc.verificationMethod.length, 3);
    assertEq(_hash(doc), GOLDEN_F2_RESOLVE_TRUE);
  }

  function test_Golden_F3_Resolve_PlainFragment() public {
    _buildF1();
    assertEq(_hash(w3cResolver.resolve(_input(FRAGMENT_PLAIN), false)), GOLDEN_F3_PLAIN);
  }

  function test_Golden_F3_Resolve_LeadingZeroFragment() public {
    _buildF1();
    assertEq(_hash(w3cResolver.resolve(_input(FRAGMENT_LEADING_ZERO), false)), GOLDEN_F3_LEADING_ZERO);
  }

  function test_Golden_F3_ResolveVm_PlainFragment() public {
    _buildF1();
    assertEq(_hash(w3cResolver.resolveVm(_input(FRAGMENT_PLAIN), VM_ID_LEADING_ZERO)), GOLDEN_F3_PLAIN_VM);
  }

  function test_Golden_F3_ResolveVm_LeadingZeroFragment() public {
    _buildF1();
    assertEq(
      _hash(w3cResolver.resolveVm(_input(FRAGMENT_LEADING_ZERO), Fixtures.VM_ID_CUSTOM)), GOLDEN_F3_LEADING_ZERO_VM
    );
  }

  /// @dev Creates a VM with every field settable, as user1 (caller must be pranked).
  function _createVmWith(
    bytes32 vmId,
    bytes1 relationships,
    bytes memory multibase,
    bytes memory account,
    address owner,
    uint88 expiration
  ) private {
    didManager.createVm(
      CreateVmCommand({
        methods: methods,
        senderId: didId,
        senderVmId: DEFAULT_VM_ID,
        targetId: didId,
        vmId: vmId,
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: multibase,
        blockchainAccountId: account,
        ethereumAddress: owner,
        relationships: relationships,
        expiration: expiration
      })
    );
  }

  function _startDefaultDid() private {
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory created = DidTestHelpers.createDefaultDid(vm, didManager);
    methods = created.didInfo.methods;
    didId = created.didInfo.id;
  }

  /// @notice F4: a VM with a non-zero ethereumAddress left unvalidated (expiration 0) is filtered by
  /// includeExpired = false and rendered with its address and expiration 0 when included.
  function test_Golden_F4_Resolve_UnvalidatedEthereumAddressVm() public {
    _startDefaultDid();
    _createVmWith(Fixtures.VM_ID_CUSTOM, 0x06, Fixtures.TEST_SECP256K1_MULTIBASE, "", user2, 0);
    _stopPrank();
    W3CDidDocument memory excluded = w3cResolver.resolve(_input(bytes32(0)), false);
    W3CDidDocument memory included = w3cResolver.resolve(_input(bytes32(0)), true);
    assertEq(excluded.verificationMethod.length, 1, "unvalidated VM is filtered out");
    assertEq(included.verificationMethod.length, 2, "unvalidated VM is listed when expired are included");
    assertEq(_hash(excluded), GOLDEN_F4_UNVALIDATED_EXCLUDE);
    assertEq(_hash(included), GOLDEN_F4_UNVALIDATED_INCLUDE);
  }

  /// @notice F5: a VM with a non-empty blockchainAccountId renders it.
  function test_Golden_F5_Resolve_BlockchainAccountId() public {
    _startDefaultDid();
    _createVmWith(
      Fixtures.VM_ID_CUSTOM, 0x03, "", Fixtures.DEFAULT_CAIP10_ACCOUNT_ID, address(0), uint88(GOLDEN_TIMESTAMP + 1 days)
    );
    _stopPrank();
    W3CVerificationMethod memory out = w3cResolver.resolveVm(_input(bytes32(0)), Fixtures.VM_ID_CUSTOM);
    assertGt(bytes(out.blockchainAccountId).length, 0);
    assertEq(_hash(w3cResolver.resolve(_input(bytes32(0)), false)), GOLDEN_F5_BLOCKCHAIN_ACCOUNT);
  }

  /// @notice F6: non-default methods accepted by checkMethods: one segment with an empty middle segment (";" filler)
  /// and three populated segments.
  function test_Golden_F6_Resolve_NonDefaultMethods() public {
    bytes32 one = HashUtils.packMethods(bytes10("lzpf"), bytes10(0), bytes10(0));
    bytes32 three = HashUtils.packMethods(bytes10("abc"), bytes10("x-Y_1"), bytes10("z.9"));
    W3CResolverBase(address(w3cResolver)).checkMethods(one);
    W3CResolverBase(address(w3cResolver)).checkMethods(three);
    _startPrank(user1);
    bytes32 idOne = DidTestHelpers.createDid(vm, didManager, one, Fixtures.DEFAULT_RANDOM_0, bytes32(0)).didInfo.id;
    bytes32 idThree = DidTestHelpers.createDid(vm, didManager, three, Fixtures.DEFAULT_RANDOM_0, bytes32(0)).didInfo.id;
    _stopPrank();
    assertEq(
      _hash(w3cResolver.resolve(W3CDidInput({ methods: one, id: idOne, fragment: FRAGMENT_PLAIN }), false)),
      GOLDEN_F6_METHODS_ONE_SEGMENT
    );
    assertEq(
      _hash(w3cResolver.resolve(W3CDidInput({ methods: three, id: idThree, fragment: bytes32(0) }), false)),
      GOLDEN_F6_METHODS_THREE_SEGMENTS
    );
  }

  /// @notice F7: createDid on an expired DID (same sender, random, methods) runs _removeAllVms and creates the same
  /// VM id again with empty key fields; nothing of the first life may leak into the second.
  function test_Golden_F7_Resolve_VmIdRecreatedAfterRemoveAll() public {
    _startDefaultDid();
    _createVmWith(
      Fixtures.VM_ID_CUSTOM,
      0x06,
      Fixtures.TEST_SECP256K1_MULTIBASE,
      Fixtures.DEFAULT_CAIP10_ACCOUNT_ID,
      address(0),
      uint88(GOLDEN_TIMESTAMP + 1 days)
    );
    didManager.deactivateDid(methods, didId, DEFAULT_VM_ID, didId);
    vm.warp(GOLDEN_TIMESTAMP + 1);
    DidTestHelpers.CreateDidResult memory again = DidTestHelpers.createDid(
      vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );
    _stopPrank();
    assertEq(again.didInfo.id, didId, "same DID id is re-created");
    W3CVerificationMethod memory out = w3cResolver.resolveVm(_input(bytes32(0)), Fixtures.VM_ID_CUSTOM);
    assertEq(bytes(out.publicKeyMultibase).length, 0, "no stale multibase");
    assertEq(bytes(out.blockchainAccountId).length, 0, "no stale account id");
    W3CDidDocument memory included = w3cResolver.resolve(_input(bytes32(0)), true);
    assertEq(included.verificationMethod.length, 1, "first-life VMs are gone");
    assertEq(_hash(included), GOLDEN_F7_RECREATED_INCLUDE);
    assertEq(_hash(w3cResolver.resolve(_input(bytes32(0)), false)), GOLDEN_F7_RECREATED_EXCLUDE);
  }
}

contract ResolverGoldenOutputNativeUnitTest is TestBaseNative, ResolverGoldenFixtures {
  using DidTestHelpersNative for *;

  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;
  address private user3 = Fixtures.TEST_USER_3;

  bytes32 private methods;
  bytes32 private didId;
  bytes32 private controllerBId;
  bytes32 private controllerCId;

  // Measured on the unmodified v1.6.0 sources (c8c1ebe).
  bytes32 private constant GOLDEN_N1_RESOLVE_FALSE = 0xae8fdf4c978e85d53bf93d2b8123e2649adb9d3d3ed47384f1822bc1d3061f7d;
  bytes32 private constant GOLDEN_N1_RESOLVE_TRUE = 0xae8fdf4c978e85d53bf93d2b8123e2649adb9d3d3ed47384f1822bc1d3061f7d;
  bytes32 private constant GOLDEN_N1_VMS = 0x5214080018458d2ca230f15ffc34218ba7c26d9e054fae9a290cbe219e594d82;
  bytes32 private constant GOLDEN_N1_SERVICES = 0x8f7fd16dbe7dbc18e27bcff2a431bf3775a91a0e789192ff8ff6b54ca4224565;
  bytes32 private constant GOLDEN_N2_RESOLVE_FALSE = 0xbb803d4b0f296c00f5c4192a9d78b2f9c64977a8996e69cf76123b0aa84e18a8;
  bytes32 private constant GOLDEN_N2_RESOLVE_TRUE = 0x0ff5744a0c3711bcd0dd91e14692d5dac8e04b3193cc8784b10dfe66cff81e1f;
  bytes32 private constant GOLDEN_N3_PLAIN = 0xcf52cc2dd0ca15bed45bf2cdce981059c5aa4e5b381cb523030539374deceb10;
  bytes32 private constant GOLDEN_N3_LEADING_ZERO = 0x57d405a8943e516d7fa18368c8912f58cb0b175bcf04827154ee75a0fcdb329f;

  // N4 and N5 were added after review and measured on the original sources (5555ebd).
  bytes32 private constant GOLDEN_N4_METHODS_ONE_SEGMENT =
    0xa8db1ada38c1153b15913c28ce48d5d6ffd5c0b90f54a8b0a1351016d27363ee;
  bytes32 private constant GOLDEN_N5_RECREATED_INCLUDE =
    0xc1e4bb4dce538343b37b41d31663e93743d3b8215925abb8b018c8f0b0fc54cf;
  bytes32 private constant GOLDEN_N5_RECREATED_EXCLUDE =
    0xc1e4bb4dce538343b37b41d31663e93743d3b8215925abb8b018c8f0b0fc54cf;

  function setUp() public {
    vm.warp(GOLDEN_TIMESTAMP);
    _deployDidManagerNative();
    _setupUser(user1, "user1");
    _setupUser(user2, "user2");
    _setupUser(user3, "user3");
  }

  function _input(bytes32 fragment) private view returns (W3CDidInput memory) {
    return W3CDidInput({ methods: methods, id: didId, fragment: fragment });
  }

  /// @dev Creates a native VM as user1 and validates it as `owner`. Leaves the caller pranked as user1.
  function _createVm(bytes32 vmId, address owner, bytes1 relationships, bytes memory multibase) private {
    vm.recordLogs();
    didManagerNative.createVm(
      CreateVmCommandNative({
        methods: methods,
        senderId: didId,
        senderVmId: DEFAULT_VM_ID_NATIVE,
        targetId: didId,
        vmId: vmId,
        ethereumAddress: owner,
        relationships: relationships,
        publicKeyMultibase: multibase
      })
    );
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 positionHash = bytes32(entries[0].data);
    _stopPrank();
    _startPrank(owner);
    didManagerNative.validateVm(positionHash, 0);
    _stopPrank();
    _startPrank(user1);
  }

  function _buildN1() private {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory created = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    methods = created.didInfo.methods;
    didId = created.didInfo.id;

    // vm-0 = auth (0x01), custom = auth + keyAgreement with multibase (0x05), leading-zero id = all but keyAgreement.
    _createVm(Fixtures.VM_ID_CUSTOM, user2, 0x05, Fixtures.TEST_SECP256K1_MULTIBASE);
    _createVm(VM_ID_LEADING_ZERO, user3, 0x1B, "");

    didManagerNative.updateService(
      methods,
      didId,
      DEFAULT_VM_ID_NATIVE,
      didId,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.SERVICE_TYPE_MULTIPLE,
      Fixtures.SERVICE_ENDPOINT_MULTIPLE
    );
    didManagerNative.updateService(
      methods,
      didId,
      DEFAULT_VM_ID_NATIVE,
      didId,
      Fixtures.SERVICE_ID_TEST_1,
      Fixtures.DEFAULT_SERVICE_TYPE,
      Fixtures.DEFAULT_SERVICE_ENDPOINT
    );

    controllerBId =
    DidTestHelpersNative.createDid(
        vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
      )
      .didInfo
      .id;
    controllerCId =
    DidTestHelpersNative.createDid(
        vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0)
      )
      .didInfo
      .id;
    didManagerNative.updateController(
      methods, didId, DEFAULT_VM_ID_NATIVE, didId, controllerBId, DEFAULT_VM_ID_NATIVE, 0
    );
    didManagerNative.updateController(methods, controllerBId, DEFAULT_VM_ID_NATIVE, didId, controllerCId, bytes32(0), 1);
    _stopPrank();
  }

  function _buildN2() private {
    _buildN1();
    _startPrank(user1);
    didManagerNative.expireVm(methods, controllerBId, DEFAULT_VM_ID_NATIVE, didId, Fixtures.VM_ID_CUSTOM);
    _stopPrank();
  }

  function test_Golden_N1_Resolve_ExcludeExpired() public {
    _buildN1();
    assertEq(_hash(w3cResolverNative.resolve(_input(bytes32(0)), false)), GOLDEN_N1_RESOLVE_FALSE);
  }

  function test_Golden_N1_Resolve_IncludeExpired() public {
    _buildN1();
    assertEq(_hash(w3cResolverNative.resolve(_input(bytes32(0)), true)), GOLDEN_N1_RESOLVE_TRUE);
  }

  function test_Golden_N1_ResolveVm_EachVm() public {
    _buildN1();
    bytes32 acc;
    bytes32[3] memory ids = [DEFAULT_VM_ID_NATIVE, Fixtures.VM_ID_CUSTOM, VM_ID_LEADING_ZERO];
    for (uint256 i = 0; i < ids.length; i++) {
      acc = keccak256(abi.encode(acc, _hash(w3cResolverNative.resolveVm(_input(bytes32(0)), ids[i]))));
    }
    assertEq(acc, GOLDEN_N1_VMS);
  }

  function test_Golden_N1_ResolveService_EachService() public {
    _buildN1();
    bytes32 acc;
    bytes32[2] memory ids = [Fixtures.DEFAULT_SERVICE_ID, Fixtures.SERVICE_ID_TEST_1];
    for (uint256 i = 0; i < ids.length; i++) {
      acc = keccak256(abi.encode(acc, _hash(w3cResolverNative.resolveService(_input(bytes32(0)), ids[i]))));
    }
    assertEq(acc, GOLDEN_N1_SERVICES);
  }

  function test_Golden_N2_Resolve_ExcludeExpired() public {
    _buildN2();
    W3CDidDocument memory doc = w3cResolverNative.resolve(_input(bytes32(0)), false);
    assertEq(doc.verificationMethod.length, 2);
    assertEq(_hash(doc), GOLDEN_N2_RESOLVE_FALSE);
  }

  function test_Golden_N2_Resolve_IncludeExpired() public {
    _buildN2();
    W3CDidDocument memory doc = w3cResolverNative.resolve(_input(bytes32(0)), true);
    assertEq(doc.verificationMethod.length, 3);
    assertEq(_hash(doc), GOLDEN_N2_RESOLVE_TRUE);
  }

  function test_Golden_N3_Resolve_PlainFragment() public {
    _buildN1();
    assertEq(_hash(w3cResolverNative.resolve(_input(FRAGMENT_PLAIN), false)), GOLDEN_N3_PLAIN);
  }

  function test_Golden_N3_Resolve_LeadingZeroFragment() public {
    _buildN1();
    assertEq(_hash(w3cResolverNative.resolve(_input(FRAGMENT_LEADING_ZERO), false)), GOLDEN_N3_LEADING_ZERO);
  }

  /// @notice N4: non-default methods with an empty middle segment (";" filler), native resolver.
  function test_Golden_N4_Resolve_NonDefaultMethods() public {
    bytes32 one = HashUtils.packMethods(bytes10("lzpf"), bytes10(0), bytes10(0));
    W3CResolverBase(address(w3cResolverNative)).checkMethods(one);
    _startPrank(user1);
    bytes32 idOne =
      DidTestHelpersNative.createDid(vm, didManagerNative, one, Fixtures.DEFAULT_RANDOM_0, bytes32(0)).didInfo.id;
    _stopPrank();
    assertEq(
      _hash(w3cResolverNative.resolve(W3CDidInput({ methods: one, id: idOne, fragment: FRAGMENT_PLAIN }), false)),
      GOLDEN_N4_METHODS_ONE_SEGMENT
    );
  }

  /// @notice N5: native VM id re-created after _removeAllVms; the keyAgreement multibase of the first life must not
  /// reappear.
  function test_Golden_N5_Resolve_VmIdRecreatedAfterRemoveAll() public {
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory created = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    methods = created.didInfo.methods;
    didId = created.didInfo.id;
    _createVm(Fixtures.VM_ID_CUSTOM, user2, 0x05, Fixtures.TEST_SECP256K1_MULTIBASE);
    didManagerNative.deactivateDid(methods, didId, DEFAULT_VM_ID_NATIVE, didId);
    vm.warp(GOLDEN_TIMESTAMP + 1);
    DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, Fixtures.VM_ID_CUSTOM
    );
    _stopPrank();
    W3CVerificationMethod memory out = w3cResolverNative.resolveVm(_input(bytes32(0)), Fixtures.VM_ID_CUSTOM);
    assertEq(bytes(out.publicKeyMultibase).length, 0, "no stale multibase");
    W3CDidDocument memory included = w3cResolverNative.resolve(_input(bytes32(0)), true);
    assertEq(included.verificationMethod.length, 1, "first-life VMs are gone");
    assertEq(_hash(included), GOLDEN_N5_RECREATED_INCLUDE);
    assertEq(_hash(w3cResolverNative.resolve(_input(bytes32(0)), false)), GOLDEN_N5_RECREATED_EXCLUDE);
  }
}
