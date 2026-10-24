// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { TestBase } from "../helpers/TestBase.sol";
import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { DidCreateVmCommandNative as CreateVmCommandNative } from "@types/VmTypesNative.sol";
import { W3CDidDocument, W3CDidInput } from "@types/W3CTypes.sol";
import { Service } from "@types/ServiceTypes.sol";
import { DEFAULT_VM_ID } from "@interfaces/IVMStorage.sol";
import { DEFAULT_VM_ID_NATIVE } from "@interfaces/IVMStorageNative.sol";
import { IServiceStorage } from "@interfaces/IServiceStorage.sol";

uint256 constant MAX_LIST = 255;

/// @dev Fixture ids shared by both variants
abstract contract ListLimitsIds {
  function _vmId(uint256 n) internal pure returns (bytes32) {
    return bytes32(uint256(0x766d0000) + n);
  }

  function _serviceId(uint256 n) internal pure returns (bytes32) {
    return bytes32(uint256(0x73760000) + n);
  }
}

/**
 * @title ListLimits unit tests
 * @notice Pins the two list limits for both variants: a DID holding the maximum 255 verification methods still
 * resolves (with includeExpired true and false), and a DID accepts at most 255 services (the 256th reverts and leaves
 * the list intact).
 * @dev The resolvers loop with a uint8 counter, which used to overflow at 255 VMs (panic 0x11); the service position
 * is a uint8 as well and used to wrap at 256 (position 0, a lost entry).
 */

contract ListLimitsFullUnitTest is TestBase, ListLimitsIds {
  address private user1 = Fixtures.TEST_USER_1;

  bytes32 private methods;
  bytes32 private id;

  function setUp() public {
    _deployDidManager();
    _setupUser(user1, "user1");
    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory r = DidTestHelpers.createDefaultDid(vm, didManager);
    methods = r.didInfo.methods;
    id = r.didInfo.id;
    _stopPrank();
  }

  /// @dev Active publicKeyMultibase VMs (no ethereum address, so no validation step), up to `total` VMs
  function _fillVms(uint256 total) private {
    _startPrank(user1);
    for (uint256 n = 1; n < total; n++) {
      didManager.createVm(
        CreateVmCommand({
          methods: methods,
          senderId: id,
          senderVmId: DEFAULT_VM_ID,
          targetId: id,
          vmId: _vmId(n),
          type_: Fixtures.defaultVmType(),
          publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase(),
          blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
          ethereumAddress: address(0),
          relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
          expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
        })
      );
    }
    _stopPrank();
  }

  function _addService(uint256 n) private {
    didManager.updateService(
      methods, id, DEFAULT_VM_ID, id, _serviceId(n), Fixtures.defaultServiceType(), Fixtures.defaultServiceEndpoint()
    );
  }

  function _input() private view returns (W3CDidInput memory) {
    return W3CDidInput({ methods: methods, id: id, fragment: bytes32(0) });
  }

  function test_Resolve_Should_ListAll255Vms_When_IncludeExpiredIsFalse() public {
    _fillVms(MAX_LIST);
    assertEq(didManager.getVmListLength(methods, id), MAX_LIST);
    uint256 g = gasleft();
    W3CDidDocument memory doc = w3cResolver.resolve(_input(), false);
    console2.log("Full resolve 255 VMs includeExpired=false gas", g - gasleft());
    assertEq(doc.verificationMethod.length, MAX_LIST);
    assertEq(doc.authentication.length, MAX_LIST);
  }

  function test_Resolve_Should_ListAll255Vms_When_IncludeExpiredIsTrue() public {
    _fillVms(MAX_LIST);
    uint256 g = gasleft();
    W3CDidDocument memory doc = w3cResolver.resolve(_input(), true);
    console2.log("Full resolve 255 VMs includeExpired=true gas", g - gasleft());
    assertEq(doc.verificationMethod.length, MAX_LIST);
    assertEq(doc.authentication.length, MAX_LIST);
  }

  function test_CreateVm_Should_Revert_When_Adding256thVm() public {
    _fillVms(MAX_LIST);
    _startPrank(user1);
    vm.expectRevert();
    didManager.createVm(
      CreateVmCommand({
        methods: methods,
        senderId: id,
        senderVmId: DEFAULT_VM_ID,
        targetId: id,
        vmId: _vmId(MAX_LIST),
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: Fixtures.defaultVmPublicKeyMultibase(),
        blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
        ethereumAddress: address(0),
        relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
        expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
      })
    );
    _stopPrank();
    assertEq(didManager.getVmListLength(methods, id), MAX_LIST);
  }

  function test_UpdateService_Should_Accept255thAndRevertOn256th_When_ListIsFull() public {
    _startPrank(user1);
    for (uint256 n = 1; n <= MAX_LIST; n++) {
      _addService(n);
    }
    assertEq(didManager.getServiceListLength(methods, id), MAX_LIST);

    vm.expectRevert(IServiceStorage.TooManyServices.selector);
    _addService(MAX_LIST + 1);

    // The failed attempt changed nothing
    assertEq(didManager.getServiceListLength(methods, id), MAX_LIST);
    Service memory byId = didManager.getService(methods, id, _serviceId(MAX_LIST), 0);
    assertEq(byId.id, _serviceId(MAX_LIST));
    Service memory byPos = didManager.getService(methods, id, bytes32(0), uint8(MAX_LIST));
    assertEq(byPos.id, _serviceId(MAX_LIST));
    // The first service is still at position 1
    assertEq(didManager.getService(methods, id, bytes32(0), 1).id, _serviceId(1));
    _stopPrank();
  }

  function test_UpdateService_Should_StillUpdateExisting_When_ListIsFull() public {
    _startPrank(user1);
    for (uint256 n = 1; n <= MAX_LIST; n++) {
      _addService(n);
    }
    didManager.updateService(
      methods,
      id,
      DEFAULT_VM_ID,
      id,
      _serviceId(7),
      Fixtures.defaultServiceType(),
      Fixtures.serviceEndpointSmartContract()
    );
    assertEq(didManager.getServiceListLength(methods, id), MAX_LIST);
    assertEq(
      didManager.getService(methods, id, _serviceId(7), 0).serviceEndpoint, Fixtures.serviceEndpointSmartContract()
    );
    _stopPrank();
  }

  function test_UpdateService_Should_AcceptNewService_When_FullListHadOneDeleted() public {
    _startPrank(user1);
    for (uint256 n = 1; n <= MAX_LIST; n++) {
      _addService(n);
    }
    didManager.updateService(
      methods, id, DEFAULT_VM_ID, id, _serviceId(3), Fixtures.emptyServiceType(), Fixtures.emptyServiceEndpoint()
    );
    assertEq(didManager.getServiceListLength(methods, id), MAX_LIST - 1);
    _addService(MAX_LIST + 1);
    assertEq(didManager.getServiceListLength(methods, id), MAX_LIST);
    _stopPrank();
  }
}

contract ListLimitsNativeUnitTest is TestBaseNative, ListLimitsIds {
  address private user1 = Fixtures.TEST_USER_1;

  bytes32 private methods;
  bytes32 private id;

  function setUp() public {
    _deployDidManagerNative();
    _setupUser(user1, "user1");
    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory r = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    methods = r.didInfo.methods;
    id = r.didInfo.id;
    _stopPrank();
  }

  /// @dev Native VMs need an ethereum address and a validation by that address to become active
  function _fillVms(uint256 total) private {
    for (uint256 n = 1; n < total; n++) {
      _startPrank(user1);
      DidTestHelpersNative.CreateVmResult memory r = DidTestHelpersNative.createVm(
        vm,
        didManagerNative,
        CreateVmCommandNative({
          methods: methods,
          senderId: id,
          senderVmId: DEFAULT_VM_ID_NATIVE,
          targetId: id,
          vmId: _vmId(n),
          ethereumAddress: user1,
          relationships: Fixtures.DEFAULT_VM_RELATIONSHIPS,
          publicKeyMultibase: ""
        })
      );
      didManagerNative.validateVm(r.vmCreatedPositionHash, 0);
      _stopPrank();
    }
  }

  function _addService(uint256 n) private {
    didManagerNative.updateService(
      methods,
      id,
      DEFAULT_VM_ID_NATIVE,
      id,
      _serviceId(n),
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
  }

  function _input() private view returns (W3CDidInput memory) {
    return W3CDidInput({ methods: methods, id: id, fragment: bytes32(0) });
  }

  function test_Resolve_Should_ListAll255Vms_When_IncludeExpiredIsFalse() public {
    _fillVms(MAX_LIST);
    assertEq(didManagerNative.getVmListLength(methods, id), MAX_LIST);
    uint256 g = gasleft();
    W3CDidDocument memory doc = w3cResolverNative.resolve(_input(), false);
    console2.log("Native resolve 255 VMs includeExpired=false gas", g - gasleft());
    assertEq(doc.verificationMethod.length, MAX_LIST);
    assertEq(doc.authentication.length, MAX_LIST);
  }

  function test_Resolve_Should_ListAll255Vms_When_IncludeExpiredIsTrue() public {
    _fillVms(MAX_LIST);
    uint256 g = gasleft();
    W3CDidDocument memory doc = w3cResolverNative.resolve(_input(), true);
    console2.log("Native resolve 255 VMs includeExpired=true gas", g - gasleft());
    assertEq(doc.verificationMethod.length, MAX_LIST);
    assertEq(doc.authentication.length, MAX_LIST);
  }

  function test_UpdateService_Should_Accept255thAndRevertOn256th_When_ListIsFull() public {
    _startPrank(user1);
    for (uint256 n = 1; n <= MAX_LIST; n++) {
      _addService(n);
    }
    assertEq(didManagerNative.getServiceListLength(methods, id), MAX_LIST);

    vm.expectRevert(IServiceStorage.TooManyServices.selector);
    _addService(MAX_LIST + 1);

    assertEq(didManagerNative.getServiceListLength(methods, id), MAX_LIST);
    assertEq(didManagerNative.getService(methods, id, _serviceId(MAX_LIST), 0).id, _serviceId(MAX_LIST));
    assertEq(didManagerNative.getService(methods, id, bytes32(0), uint8(MAX_LIST)).id, _serviceId(MAX_LIST));
    assertEq(didManagerNative.getService(methods, id, bytes32(0), 1).id, _serviceId(1));
    _stopPrank();
  }
}
