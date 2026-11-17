// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { ContractVmFullBase, ContractVmNativeBase, CasesBase, IManager } from "@test/unit/ContractVm.unit.t.sol";
import { Fixtures } from "@test/helpers/Fixtures.sol";
import { ReferenceIssuer } from "@test/mocks/MockContractKeys.sol";
import { ERC1271_MAGIC_VALUE } from "@test/mocks/MockERC1271Wallets.sol";
import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @dev Mirrors VClaimManager._authorize: only a sender holding an assertion key of the issuer DID may issue.
contract ClaimSink {
  error IssuerNotAuthorized();

  IManager internal immutable MANAGER;
  uint256 public count;

  constructor(address manager) {
    MANAGER = IManager(manager);
  }

  function issue(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 issuerDid) external {
    if (!MANAGER.isAuthorized(methods, senderId, senderVmId, issuerDid, 0x02, msg.sender)) {
      revert IssuerNotAuthorized();
    }
    count++;
  }
}

/// @dev ERC-1271 wallet that accepts its owner key's signature and validates its own VM.
contract SelfValidatingWallet {
  address public immutable OWNER_KEY;

  constructor(address ownerKey) {
    OWNER_KEY = ownerKey;
  }

  function validate(address manager, bytes32 positionHash) external {
    IDidWriteOps(manager).validateVm(positionHash, 0);
  }

  function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
    (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
    if (err == ECDSA.RecoverError.NoError && recovered == OWNER_KEY) return ERC1271_MAGIC_VALUE;
    return 0xffffffff;
  }
}

abstract contract IssuerCases is CasesBase {
  bytes32 internal constant MESSAGE_HASH = keccak256("issuer-integration-challenge");

  ClaimSink internal sink;
  ReferenceIssuer internal issuer;
  bytes32 internal methodsB;
  bytes32 internal didB;

  function _setUpIssuer() internal {
    sink = new ClaimSink(_mgr());
    (methodsB, didB) = _newDid(owner, bytes32("did-b"));
    issuer = new ReferenceIssuer(_mgr(), admin);
    bytes32 pos = _newVm(owner, methodsB, didB, VM_T, address(issuer), R_ASSERTION);
    vm.prank(admin, admin);
    issuer.validate(pos);
  }

  function _issueData(bytes32 target) internal view returns (bytes memory) {
    return abi.encodeCall(ClaimSink.issue, (methodsB, didB, VM_T, target));
  }

  function _issueThroughIssuer(bytes32 target) internal {
    vm.prank(admin, admin);
    issuer.exec(address(sink), _issueData(target));
  }

  function _expectIssueRejected(bytes32 target) internal {
    vm.prank(admin, admin);
    vm.expectRevert(ClaimSink.IssuerNotAuthorized.selector);
    issuer.exec(address(sink), _issueData(target));
  }

  function _makeBControllerOf(address targetOwner, bytes32 targetDid) internal {
    vm.prank(targetOwner, targetOwner);
    IManager(_mgr()).updateController(methodsB, targetDid, _defaultVmId(), targetDid, didB, bytes32(0), 0);
  }

  function test_Integration_IssuerContract_IssuesInNameOfItsDid() public {
    _issueThroughIssuer(didB);
    assertEq(sink.count(), 1, "issuer contract issued in the name of its DID");

    // The owner EOA does not hold the issuer's VM key.
    vm.prank(owner, owner);
    vm.expectRevert(ClaimSink.IssuerNotAuthorized.selector);
    sink.issue(methodsB, didB, VM_T, didB);
    assertEq(sink.count(), 1, "count unchanged");
  }

  function test_Integration_IssuerContract_ActsForControlledDid() public {
    address ownerT = makeAddr("owner-t");
    (bytes32 mT, bytes32 didT) = _newDid(ownerT, bytes32("did-t"));
    assertEq(mT, methodsB, "same methods");
    (, bytes32 didOther) = _newDid(stranger, bytes32("did-other"));
    _makeBControllerOf(ownerT, didT);

    _issueThroughIssuer(didT);
    assertEq(sink.count(), 1, "issuer acts for the DID B controls");

    _expectIssueRejected(didOther);
    assertEq(sink.count(), 1, "a DID B does not control is rejected");
  }

  function test_Integration_IssuerContract_StopsWhenKeyIsExpired() public {
    address ownerT = makeAddr("owner-t");
    (, bytes32 didT) = _newDid(ownerT, bytes32("did-t"));
    _makeBControllerOf(ownerT, didT);
    _issueThroughIssuer(didB);
    _issueThroughIssuer(didT);
    assertEq(sink.count(), 2, "both calls work before expiry");

    vm.prank(owner, owner);
    IManager(_mgr()).expireVm(methodsB, didB, _defaultVmId(), didB, VM_T);

    _expectIssueRejected(didB);
    _expectIssueRejected(didT);
    assertEq(sink.count(), 2, "count unchanged after expiry");
  }

  function test_Integration_ContractKey_OffChainPath() public {
    uint256 pk = Fixtures.TEST_PK_1;
    SelfValidatingWallet wallet = new SelfValidatingWallet(vm.addr(pk));
    bytes32 pos = _newVm(owner, methodsB, didB, bytes32("vm-wallet"), address(wallet), R_ASSERTION);
    wallet.validate(_mgr(), pos);
    assertTrue(_auth(methodsB, didB, bytes32("vm-wallet"), R_ASSERTION, address(wallet)), "wallet VM validated");

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, MESSAGE_HASH);

    assertTrue(
      IManager(_mgr())
        .isAuthorizedOffChainWithSigner(
          methodsB,
          didB,
          bytes32("vm-wallet"),
          didB,
          R_ASSERTION,
          address(wallet),
          MESSAGE_HASH,
          abi.encodePacked(r, s, v)
        ),
      "ERC-1271 wallet authorizes with its owner key"
    );
    assertFalse(
      IManager(_mgr())
        .isAuthorizedOffChain(methodsB, didB, bytes32("vm-wallet"), didB, R_ASSERTION, MESSAGE_HASH, v, r, s),
      "ecrecover path cannot see a contract key"
    );
    assertFalse(
      IManager(_mgr())
        .isAuthorizedOffChainWithSigner(
          methodsB, didB, VM_T, didB, R_ASSERTION, address(issuer), MESSAGE_HASH, abi.encodePacked(r, s, v)
        ),
      "a contract without isValidSignature cannot sign"
    );
  }
}

contract ContractIssuerIntegrationTest is IssuerCases, ContractVmFullBase {
  function setUp() public {
    _deployDidManager();
    _setUpIssuer();
  }
}

contract ContractIssuerNativeIntegrationTest is IssuerCases, ContractVmNativeBase {
  function setUp() public {
    _deployDidManagerNative();
    _setUpIssuer();
  }
}
