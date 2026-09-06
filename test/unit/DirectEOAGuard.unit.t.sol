// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { TestBase } from "@test/helpers/TestBase.sol";
import { TestBaseNative } from "@test/helpers/TestBaseNative.sol";
import { DidTestHelpers } from "@test/helpers/DidTestHelpers.sol";
import { DidTestHelpersNative } from "@test/helpers/DidTestHelpersNative.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { DidCreateVmCommand as CreateVmCommand } from "@types/VmTypes.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { DidCreateVmCommandNative as NativeCreateVmCommand } from "@types/VmTypesNative.sol";
import { DEFAULT_VM_ID, IVMStorage } from "@interfaces/IVMStorage.sol";
import { DEFAULT_VM_ID_NATIVE, IVMStorageNative } from "@interfaces/IVMStorageNative.sol";
import "@types/DidTypes.sol";

// =========================================================================
// Attacker Mocks (confused-deputy intermediaries)
// =========================================================================

/// @dev Simulates a malicious (or merely compromised) contract the victim interacts with.
/// Every forwarder runs with msg.sender = this contract while tx.origin = victim EOA —
/// exactly the call shape the onlyDirectEOA guard must reject.
contract MaliciousIntermediary {
  IDidManagerFull internal immutable didManager;

  constructor(IDidManagerFull didManager_) {
    didManager = didManager_;
  }

  function attackCreateDid(bytes32 methods, bytes32 random, bytes32 vmId) external {
    didManager.createDid(methods, random, vmId);
  }

  function attackCreateVm(CreateVmCommand memory command) external {
    didManager.createVm(command);
  }

  function attackValidateVm(bytes32 positionHash, uint256 expiration) external {
    didManager.validateVm(positionHash, expiration);
  }

  function attackExpireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId)
    external
  {
    didManager.expireVm(methods, senderId, senderVmId, targetId, vmId);
  }

  function attackDeactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    didManager.deactivateDid(methods, senderId, senderVmId, targetId);
  }

  function attackReactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    didManager.reactivateDid(methods, senderId, senderVmId, targetId);
  }

  function attackUpdateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external {
    didManager.updateController(
      methods, senderId, senderVmId, targetId, controllerId, controllerVmId, controllerPosition
    );
  }

  function attackUpdateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external {
    didManager.updateService(methods, senderId, senderVmId, targetId, serviceId, type_, serviceEndpoint);
  }
}

/// @dev Native-variant twin of MaliciousIntermediary.
contract MaliciousIntermediaryNative {
  IDidManagerNative internal immutable didManager;

  constructor(IDidManagerNative didManager_) {
    didManager = didManager_;
  }

  function attackCreateDid(bytes32 methods, bytes32 random, bytes32 vmId) external {
    didManager.createDid(methods, random, vmId);
  }

  function attackCreateVm(NativeCreateVmCommand memory command) external {
    didManager.createVm(command);
  }

  function attackValidateVm(bytes32 positionHash, uint256 expiration) external {
    didManager.validateVm(positionHash, expiration);
  }

  function attackExpireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId)
    external
  {
    didManager.expireVm(methods, senderId, senderVmId, targetId, vmId);
  }

  function attackDeactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    didManager.deactivateDid(methods, senderId, senderVmId, targetId);
  }

  function attackReactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId) external {
    didManager.reactivateDid(methods, senderId, senderVmId, targetId);
  }

  function attackUpdateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external {
    didManager.updateController(
      methods, senderId, senderVmId, targetId, controllerId, controllerVmId, controllerPosition
    );
  }

  function attackUpdateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external {
    didManager.updateService(methods, senderId, senderVmId, targetId, serviceId, type_, serviceEndpoint);
  }
}

// =========================================================================
// Full W3C Variant Tests
// =========================================================================

contract DirectEOAGuardUnitTest is TestBase {
  address internal victim = Fixtures.TEST_USER_1;
  address internal user2 = Fixtures.TEST_USER_2;

  MaliciousIntermediary internal attacker;
  DidTestHelpers.CreateDidResult internal victimDid;

  function setUp() public {
    _deployDidManager();
    _setupUser(victim, "Victim");
    _setupUser(user2, "User2");
    attacker = new MaliciousIntermediary(didManager);

    // Victim registers a DID directly — the identity the intermediary will try to hijack
    _startPrank(victim);
    victimDid = DidTestHelpers.createDefaultDid(vm, didManager);
    _stopPrank();
  }

  // =========================================================================
  // NEGATIVE PATHS — tx.origin == victim (registered EOA), msg.sender == attacker contract.
  // Under the pre-v1.4.0 tx.origin auth these calls would have authenticated as the victim;
  // they must now revert DirectEOACallRequired before any state is touched.
  // =========================================================================

  function test_CreateDid_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackCreateDid(Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
  }

  function test_CreateVm_Should_Revert_When_CalledThroughIntermediary() public {
    CreateVmCommand memory command = CreateVmCommand({
      methods: victimDid.didInfo.methods,
      senderId: victimDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID,
      targetId: victimDid.didInfo.id,
      vmId: bytes32("vm-attack"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: user2,
      relationships: bytes1(0x01),
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackCreateVm(command);
  }

  function test_ValidateVm_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackValidateVm(bytes32("any-position-hash"), 0);
  }

  function test_ExpireVm_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackExpireVm(
      victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID, victimDid.didInfo.id, DEFAULT_VM_ID
    );
  }

  function test_DeactivateDid_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackDeactivateDid(victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID, victimDid.didInfo.id);
  }

  function test_ReactivateDid_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackReactivateDid(victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID, victimDid.didInfo.id);
  }

  function test_UpdateController_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackUpdateController(
      victimDid.didInfo.methods,
      victimDid.didInfo.id,
      DEFAULT_VM_ID,
      victimDid.didInfo.id,
      victimDid.didInfo.id,
      DEFAULT_VM_ID,
      0
    );
  }

  function test_UpdateService_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackUpdateService(
      victimDid.didInfo.methods,
      victimDid.didInfo.id,
      DEFAULT_VM_ID,
      victimDid.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
  }

  // =========================================================================
  // POSITIVE PATHS — direct EOA calls (msg.sender == tx.origin) pass everywhere
  // =========================================================================

  /// @notice Full lifecycle through every guarded entry point as a direct EOA
  function test_OnlyDirectEOA_Should_AllowFullLifecycle_When_CalledDirectly() public {
    _startPrank(victim);
    bytes32 methods = victimDid.didInfo.methods;
    bytes32 id = victimDid.didInfo.id;

    // createVm + validateVm (second VM owned by victim)
    CreateVmCommand memory command = CreateVmCommand({
      methods: methods,
      senderId: id,
      senderVmId: DEFAULT_VM_ID,
      targetId: id,
      vmId: bytes32("vm-extra"),
      type_: Fixtures.defaultVmType(),
      publicKeyMultibase: Fixtures.emptyVmPublicKeyMultibase(),
      blockchainAccountId: Fixtures.emptyVmBlockchainAccountId(),
      ethereumAddress: victim,
      relationships: bytes1(0x01),
      expiration: uint88(Fixtures.EMPTY_VM_EXPIRATION)
    });
    DidTestHelpers.CreateVmResult memory vmResult = DidTestHelpers.createVm(vm, didManager, command);
    didManager.validateVm(vmResult.vmCreatedPositionHash, 0);

    // updateService + updateController (self as controller)
    didManager.updateService(
      methods,
      id,
      DEFAULT_VM_ID,
      id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
    didManager.updateController(methods, id, DEFAULT_VM_ID, id, id, DEFAULT_VM_ID, 0);

    // expireVm (the second VM), deactivate, reactivate
    didManager.expireVm(methods, id, DEFAULT_VM_ID, id, bytes32("vm-extra"));
    didManager.deactivateDid(methods, id, DEFAULT_VM_ID, id);
    didManager.reactivateDid(methods, id, DEFAULT_VM_ID, id);
    _stopPrank();

    assertTrue(
      didManager.isAuthorized(methods, id, DEFAULT_VM_ID, id, bytes1(0x01), victim),
      "Victim should remain authorized after full direct-EOA lifecycle"
    );
  }

  /// @notice createDid attributes identity to msg.sender (the signing EOA), not anyone else
  function test_CreateDid_Should_BindInitialVmToMsgSender_When_CalledDirectly() public {
    assertTrue(
      didManager.isAuthorized(
        victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID, victimDid.didInfo.id, bytes1(0x01), victim
      ),
      "DID creator (msg.sender) should be authorized on the initial VM"
    );
    assertFalse(
      didManager.isAuthorized(
        victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID, victimDid.didInfo.id, bytes1(0x01), user2
      ),
      "Non-creator should not be authorized on the initial VM"
    );
  }
}

// =========================================================================
// Ethereum-Native Variant Tests
// =========================================================================

contract DirectEOAGuardNativeUnitTest is TestBaseNative {
  address internal victim = Fixtures.TEST_USER_1;
  address internal user2 = Fixtures.TEST_USER_2;

  MaliciousIntermediaryNative internal attacker;
  DidTestHelpersNative.CreateDidResult internal victimDid;

  function setUp() public {
    _deployDidManagerNative();
    _setupUser(victim, "Victim");
    _setupUser(user2, "User2");
    attacker = new MaliciousIntermediaryNative(didManagerNative);

    _startPrank(victim);
    victimDid = DidTestHelpersNative.createDefaultDid(vm, didManagerNative);
    _stopPrank();
  }

  // =========================================================================
  // NEGATIVE PATHS
  // =========================================================================

  function test_CreateDid_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackCreateDid(Fixtures.EMPTY_DID_METHODS, Fixtures.DEFAULT_RANDOM_1, bytes32(0));
  }

  function test_CreateVm_Should_Revert_When_CalledThroughIntermediary() public {
    NativeCreateVmCommand memory command = NativeCreateVmCommand({
      methods: victimDid.didInfo.methods,
      senderId: victimDid.didInfo.id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: victimDid.didInfo.id,
      vmId: bytes32("vm-attack"),
      ethereumAddress: user2,
      relationships: bytes1(0x01),
      publicKeyMultibase: ""
    });
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackCreateVm(command);
  }

  function test_ValidateVm_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackValidateVm(bytes32("any-position-hash"), 0);
  }

  function test_ExpireVm_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackExpireVm(
      victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID_NATIVE, victimDid.didInfo.id, DEFAULT_VM_ID_NATIVE
    );
  }

  function test_DeactivateDid_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackDeactivateDid(
      victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID_NATIVE, victimDid.didInfo.id
    );
  }

  function test_ReactivateDid_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackReactivateDid(
      victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID_NATIVE, victimDid.didInfo.id
    );
  }

  function test_UpdateController_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackUpdateController(
      victimDid.didInfo.methods,
      victimDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      victimDid.didInfo.id,
      victimDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      0
    );
  }

  function test_UpdateService_Should_Revert_When_CalledThroughIntermediary() public {
    vm.prank(victim, victim);
    vm.expectRevert(DirectEOACallRequired.selector);
    attacker.attackUpdateService(
      victimDid.didInfo.methods,
      victimDid.didInfo.id,
      DEFAULT_VM_ID_NATIVE,
      victimDid.didInfo.id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
  }

  // =========================================================================
  // POSITIVE PATHS
  // =========================================================================

  /// @notice Full lifecycle through every guarded entry point as a direct EOA
  function test_OnlyDirectEOA_Should_AllowFullLifecycle_When_CalledDirectly() public {
    _startPrank(victim);
    bytes32 methods = victimDid.didInfo.methods;
    bytes32 id = victimDid.didInfo.id;

    NativeCreateVmCommand memory command = NativeCreateVmCommand({
      methods: methods,
      senderId: id,
      senderVmId: DEFAULT_VM_ID_NATIVE,
      targetId: id,
      vmId: bytes32("vm-extra"),
      ethereumAddress: victim,
      relationships: bytes1(0x01),
      publicKeyMultibase: ""
    });
    DidTestHelpersNative.CreateVmResult memory vmResult = DidTestHelpersNative.createVm(vm, didManagerNative, command);
    didManagerNative.validateVm(vmResult.vmCreatedPositionHash, 0);

    didManagerNative.updateService(
      methods,
      id,
      DEFAULT_VM_ID_NATIVE,
      id,
      Fixtures.DEFAULT_SERVICE_ID,
      Fixtures.defaultServiceType(),
      Fixtures.defaultServiceEndpoint()
    );
    didManagerNative.updateController(methods, id, DEFAULT_VM_ID_NATIVE, id, id, DEFAULT_VM_ID_NATIVE, 0);
    didManagerNative.expireVm(methods, id, DEFAULT_VM_ID_NATIVE, id, bytes32("vm-extra"));
    didManagerNative.deactivateDid(methods, id, DEFAULT_VM_ID_NATIVE, id);
    didManagerNative.reactivateDid(methods, id, DEFAULT_VM_ID_NATIVE, id);
    _stopPrank();

    assertTrue(
      didManagerNative.isAuthorized(methods, id, DEFAULT_VM_ID_NATIVE, id, bytes1(0x01), victim),
      "Victim should remain authorized after full direct-EOA lifecycle"
    );
  }

  /// @notice createDid attributes identity to msg.sender (the signing EOA), not anyone else
  function test_CreateDid_Should_BindInitialVmToMsgSender_When_CalledDirectly() public {
    assertTrue(
      didManagerNative.isAuthorized(
        victimDid.didInfo.methods,
        victimDid.didInfo.id,
        DEFAULT_VM_ID_NATIVE,
        victimDid.didInfo.id,
        bytes1(0x01),
        victim
      ),
      "DID creator (msg.sender) should be authorized on the initial VM"
    );
    assertFalse(
      didManagerNative.isAuthorized(
        victimDid.didInfo.methods, victimDid.didInfo.id, DEFAULT_VM_ID_NATIVE, victimDid.didInfo.id, bytes1(0x01), user2
      ),
      "Non-creator should not be authorized on the initial VM"
    );
  }
}
