// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Vm } from "forge-std/Vm.sol";
import { DidCreateVmCommand } from "@types/VmTypes.sol";
import { DidCreateVmCommandNative } from "@types/VmTypesNative.sol";
import { TestBase } from "../helpers/TestBase.sol";
import { Fixtures } from "../helpers/Fixtures.sol";
import { DidTestHelpers } from "../helpers/DidTestHelpers.sol";
import { Controller, CONTROLLERS_MAX_LENGTH, NotAControllerForTargetId } from "@types/DidTypes.sol";
import { DEFAULT_VM_ID } from "@interfaces/IVMStorage.sol";
import { TestBaseNative } from "../helpers/TestBaseNative.sol";
import { DidTestHelpersNative } from "../helpers/DidTestHelpersNative.sol";
import { DEFAULT_VM_ID_NATIVE } from "@interfaces/IVMStorageNative.sol";

/**
 * @title SparseControllers unit tests
 * @notice Pins controller checks when ONLY one controller slot is set (position 3, and the last slot 4), and that a
 * controller entry carrying a vmId refuses a different VM of the controller DID, for both variants.
 * @dev Added before the gas pass touched _isControllerFor: the loop must not stop at an empty slot.
 */

contract SparseControllersUnitTest is TestBase {
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;
  address private user3 = Fixtures.TEST_USER_3;

  bytes32 private constant VM = DEFAULT_VM_ID;

  bytes32 private methods;
  bytes32 private targetId;
  bytes32 private controllerId;
  bytes32 private thirdId;

  function setUp() public {
    _deployDidManager();
    address[] memory users = new address[](3);
    string[] memory labels = new string[](3);
    users[0] = user1;
    labels[0] = "user1";
    users[1] = user2;
    labels[1] = "user2";
    users[2] = user3;
    labels[2] = "user3";
    _setupUsers(users, labels);

    _startPrank(user1);
    DidTestHelpers.CreateDidResult memory t =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0));
    _stopPrank();
    _startPrank(user2);
    DidTestHelpers.CreateDidResult memory c =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
    _stopPrank();
    _startPrank(user3);
    DidTestHelpers.CreateDidResult memory o =
      DidTestHelpers.createDid(vm, didManager, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0));
    _stopPrank();
    methods = t.didInfo.methods;
    targetId = t.didInfo.id;
    controllerId = c.didInfo.id;
    thirdId = o.didInfo.id;
  }

  /// @dev Sets the controller ONLY at `position`; every other slot stays empty.
  function _setSparse(bytes32 controllerVmId, uint8 position) private {
    _startPrank(user1);
    didManager.updateController(methods, targetId, VM, targetId, controllerId, controllerVmId, position);
    _stopPrank();
    Controller[CONTROLLERS_MAX_LENGTH] memory list = didManager.getControllerList(methods, targetId);
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(list[i].id, i == position ? controllerId : bytes32(0));
    }
  }

  function _checks(bytes32 controllerVmId, uint8 position) private {
    _setSparse(controllerVmId, position);

    // 1. controller DID writes on the target
    _startPrank(user2);
    didManager.updateService(methods, controllerId, VM, targetId, bytes32("svc"), bytes("Type"), bytes("https://a.io"));
    _stopPrank();
    assertEq(didManager.getServiceListLength(methods, targetId), 1);

    // 2. target's own VM can no longer write to itself
    _startPrank(user1);
    vm.expectRevert(NotAControllerForTargetId.selector);
    didManager.updateService(methods, targetId, VM, targetId, bytes32("svc2"), bytes("Type"), bytes("https://b.io"));
    _stopPrank();

    // 3. isAuthorized
    assertTrue(
      didManager.isAuthorized(methods, controllerId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user2)
    );
    assertFalse(
      didManager.isAuthorized(methods, targetId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user1)
    );

    // 4. a third DID is not a controller
    _startPrank(user3);
    vm.expectRevert(NotAControllerForTargetId.selector);
    didManager.updateService(methods, thirdId, VM, targetId, bytes32("svc3"), bytes("Type"), bytes("https://c.io"));
    _stopPrank();
    assertFalse(
      didManager.isAuthorized(methods, thirdId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user3)
    );
  }

  function test_SparseController_Should_ActAsController_When_OnlyPosition3SetWithVmId() public {
    _checks(VM, 3);
  }

  function test_SparseController_Should_ActAsController_When_OnlyPosition3SetWithoutVmId() public {
    _checks(bytes32(0), 3);
  }

  bytes32 private constant ALT_VM = bytes32("vm_alt");

  /// @dev Gives the controller DID a second, validated VM owned by user2 with authentication.
  function _createAltVm() private {
    _startPrank(user2);
    vm.recordLogs();
    didManager.createVm(
      DidCreateVmCommand({
        methods: methods,
        senderId: controllerId,
        senderVmId: VM,
        targetId: controllerId,
        vmId: ALT_VM,
        type_: Fixtures.defaultVmType(),
        publicKeyMultibase: "",
        blockchainAccountId: "",
        ethereumAddress: user2,
        relationships: 0x01,
        expiration: 0
      })
    );
    Vm.Log[] memory entries = vm.getRecordedLogs();
    didManager.validateVm(bytes32(entries[0].data), 0);
    _stopPrank();
  }

  /// @notice The entry names VM `vm-0` of the controller DID; another valid VM of that DID is refused.
  function test_SparseController_Should_RefuseOtherVm_When_EntryHasVmId() public {
    _setSparse(VM, 3);
    _createAltVm();

    // Control: the named VM is accepted.
    assertTrue(
      didManager.isAuthorized(methods, controllerId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user2)
    );
    // The same DID and the same owner, but a different VM: refused.
    assertFalse(
      didManager.isAuthorized(methods, controllerId, ALT_VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user2)
    );
    _startPrank(user2);
    vm.expectRevert(NotAControllerForTargetId.selector);
    didManager.updateService(
      methods, controllerId, ALT_VM, targetId, bytes32("svc"), bytes("Type"), bytes("https://a.io")
    );
    _stopPrank();
    assertEq(didManager.getServiceListLength(methods, targetId), 0);
  }

  /// @notice A controller only in the last slot (4) is found by the loop, with and without a vmId.
  function test_SparseController_Should_ActAsController_When_OnlyLastPositionSetWithVmId() public {
    _checks(VM, 4);
  }

  function test_SparseController_Should_ActAsController_When_OnlyLastPositionSetWithoutVmId() public {
    _checks(bytes32(0), 4);
  }
}

contract SparseControllersNativeUnitTest is TestBaseNative {
  address private user1 = Fixtures.TEST_USER_1;
  address private user2 = Fixtures.TEST_USER_2;
  address private user3 = Fixtures.TEST_USER_3;

  bytes32 private constant VM = DEFAULT_VM_ID_NATIVE;

  bytes32 private methods;
  bytes32 private targetId;
  bytes32 private controllerId;
  bytes32 private thirdId;

  function setUp() public {
    _deployDidManagerNative();
    address[] memory users = new address[](3);
    string[] memory labels = new string[](3);
    users[0] = user1;
    labels[0] = "user1";
    users[1] = user2;
    labels[1] = "user2";
    users[2] = user3;
    labels[2] = "user3";
    _setupUsers(users, labels);

    _startPrank(user1);
    DidTestHelpersNative.CreateDidResult memory t = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_0, bytes32(0)
    );
    _stopPrank();
    _startPrank(user2);
    DidTestHelpersNative.CreateDidResult memory c = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0)
    );
    _stopPrank();
    _startPrank(user3);
    DidTestHelpersNative.CreateDidResult memory o = DidTestHelpersNative.createDid(
      vm, didManagerNative, Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_2, bytes32(0)
    );
    _stopPrank();
    methods = t.didInfo.methods;
    targetId = t.didInfo.id;
    controllerId = c.didInfo.id;
    thirdId = o.didInfo.id;
  }

  /// @dev Sets the controller ONLY at `position`; every other slot stays empty.
  function _setSparse(bytes32 controllerVmId, uint8 position) private {
    _startPrank(user1);
    didManagerNative.updateController(methods, targetId, VM, targetId, controllerId, controllerVmId, position);
    _stopPrank();
    Controller[CONTROLLERS_MAX_LENGTH] memory list = didManagerNative.getControllerList(methods, targetId);
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      assertEq(list[i].id, i == position ? controllerId : bytes32(0));
    }
  }

  function _checks(bytes32 controllerVmId, uint8 position) private {
    _setSparse(controllerVmId, position);

    // 1. controller DID writes on the target
    _startPrank(user2);
    didManagerNative.updateService(
      methods, controllerId, VM, targetId, bytes32("svc"), bytes("Type"), bytes("https://a.io")
    );
    _stopPrank();
    assertEq(didManagerNative.getServiceListLength(methods, targetId), 1);

    // 2. target's own VM can no longer write to itself
    _startPrank(user1);
    vm.expectRevert(NotAControllerForTargetId.selector);
    didManagerNative.updateService(
      methods, targetId, VM, targetId, bytes32("svc2"), bytes("Type"), bytes("https://b.io")
    );
    _stopPrank();

    // 3. isAuthorized
    assertTrue(
      didManagerNative.isAuthorized(
        methods, controllerId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user2
      )
    );
    assertFalse(
      didManagerNative.isAuthorized(methods, targetId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user1)
    );

    // 4. a third DID is not a controller
    _startPrank(user3);
    vm.expectRevert(NotAControllerForTargetId.selector);
    didManagerNative.updateService(
      methods, thirdId, VM, targetId, bytes32("svc3"), bytes("Type"), bytes("https://c.io")
    );
    _stopPrank();
    assertFalse(
      didManagerNative.isAuthorized(methods, thirdId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user3)
    );
  }

  function test_SparseController_Should_ActAsController_When_OnlyPosition3SetWithVmId() public {
    _checks(VM, 3);
  }

  function test_SparseController_Should_ActAsController_When_OnlyPosition3SetWithoutVmId() public {
    _checks(bytes32(0), 3);
  }

  bytes32 private constant ALT_VM = bytes32("vm_alt");

  /// @dev Gives the controller DID a second, validated VM owned by user2 with authentication.
  function _createAltVm() private {
    _startPrank(user2);
    vm.recordLogs();
    didManagerNative.createVm(
      DidCreateVmCommandNative({
        methods: methods,
        senderId: controllerId,
        senderVmId: VM,
        targetId: controllerId,
        vmId: ALT_VM,
        ethereumAddress: user2,
        relationships: 0x01,
        publicKeyMultibase: ""
      })
    );
    Vm.Log[] memory entries = vm.getRecordedLogs();
    didManagerNative.validateVm(bytes32(entries[0].data), 0);
    _stopPrank();
  }

  /// @notice The entry names VM `vm-0` of the controller DID; another valid VM of that DID is refused.
  function test_SparseController_Should_RefuseOtherVm_When_EntryHasVmId() public {
    _setSparse(VM, 3);
    _createAltVm();

    // Control: the named VM is accepted.
    assertTrue(
      didManagerNative.isAuthorized(
        methods, controllerId, VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user2
      )
    );
    // The same DID and the same owner, but a different VM: refused.
    assertFalse(
      didManagerNative.isAuthorized(
        methods, controllerId, ALT_VM, targetId, Fixtures.VM_RELATIONSHIPS_AUTHENTICATION, user2
      )
    );
    _startPrank(user2);
    vm.expectRevert(NotAControllerForTargetId.selector);
    didManagerNative.updateService(
      methods, controllerId, ALT_VM, targetId, bytes32("svc"), bytes("Type"), bytes("https://a.io")
    );
    _stopPrank();
    assertEq(didManagerNative.getServiceListLength(methods, targetId), 0);
  }

  /// @notice A controller only in the last slot (4) is found by the loop, with and without a vmId.
  function test_SparseController_Should_ActAsController_When_OnlyLastPositionSetWithVmId() public {
    _checks(VM, 4);
  }

  function test_SparseController_Should_ActAsController_When_OnlyLastPositionSetWithoutVmId() public {
    _checks(bytes32(0), 4);
  }
}
