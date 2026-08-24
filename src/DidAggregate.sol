// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager } from "@interfaces/IDidManager.sol";
import { ServiceStorage } from "@storage/ServiceStorage.sol";
import { VMHooks } from "@storage/VMHooks.sol";
import { Service } from "@types/ServiceTypes.sol";
import { HashUtils } from "@src/HashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
  Controller,
  EXPIRATION,
  CONTROLLERS_MAX_LENGTH,
  MissingRequiredParameter,
  DidExpired,
  NotAuthenticatedAsSenderId,
  NotAControllerForTargetId,
  DidNotDeactivated,
  VmRelationshipOutOfRange,
  DirectEOACallRequired,
  METHOD_FILLER,
  MethodNameEmpty,
  MethodCharInvalid,
  MethodFillerNotTrailing,
  MethodSegmentsNotLeftPacked,
  MethodPaddingMustBeSemicolon
} from "@types/DidTypes.sol";

/// @title DidAggregate
/// @author Miguel Gomez Carpena
/// @dev Abstract aggregate root: all shared DID lifecycle, auth, controllers, services.
/// Both DidManager (full W3C) and DidManagerNative (Ethereum-native) inherit from this.
/// Contains ALL shared logic — concrete managers only implement variant-specific functions.
/// VM hooks inherited from VMHooks (shared ancestor with VMStorage variants — no diamond).
abstract contract DidAggregate is IDidManager, ServiceStorage, VMHooks {
  // ═══════════════════════════════════════════════════════════════════
  // Storage
  // ═══════════════════════════════════════════════════════════════════

  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint256) internal _expirationDate;
  // hash(method0:method1:method2:id) --> controller[0..4]
  mapping(bytes32 => Controller[CONTROLLERS_MAX_LENGTH]) internal _controllers;

  // ═══════════════════════════════════════════════════════════════════
  // Modifiers
  // ═══════════════════════════════════════════════════════════════════

  /// @dev Restricts authenticated state-changing entry points to direct EOA calls.
  /// Passes only when msg.sender is the transaction's signing EOA (msg.sender == tx.origin).
  /// This preserves the signature-derived identity guarantee and closes the confused-deputy hole
  /// that `tx.origin`-based authentication left open: a separate contract the user calls cannot
  /// act on the user's DID, because it would be msg.sender and the guard would reject it.
  /// tx.origin survives ONLY in this equality guard, never as an identity source.
  ///
  /// LIMIT (EIP-7702, live since Pectra): the guard does NOT prove "no intermediary contract is
  /// in the call chain". A delegated EOA carries code, so a call it makes to this contract still
  /// satisfies msg.sender == tx.origin. If that account's delegate executes arbitrary calls for
  /// arbitrary callers, a contract can reach a guarded entry point through it. What the guard
  /// still guarantees is narrower and is the property the authorization model needs: the
  /// authenticated address is exactly the account that signed the transaction. Choosing a
  /// delegate that lets third parties act as you is a decision made at the wallet, not here.
  modifier onlyDirectEOA() {
    if (msg.sender != tx.origin) {
      revert DirectEOACallRequired();
    }
    _;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Shared write operations (IDidWriteOps — WRITTEN ONCE)
  // ═══════════════════════════════════════════════════════════════════

  function validateVm(bytes32 positionHash, uint256 expiration) external onlyDirectEOA {
    _validateVm(positionHash, expiration, msg.sender);
  }

  function expireVm(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId, bytes32 vmId)
    external
    onlyDirectEOA
  {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _expireVm(targetIdHash, vmId);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function deactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId)
    external
    onlyDirectEOA
  {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    emit DidDeactivated(targetIdHash);
    updateExpiration({ idHash: targetIdHash, forceExpire: true });
  }

  /// @dev Reactivates a deactivated DID. Authenticates msg.sender; the onlyDirectEOA guard enforces
  /// direct EOA calls so intermediary contracts cannot impersonate the signing EOA.
  function reactivateDid(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId)
    external
    onlyDirectEOA
  {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    bytes32 senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    bytes32 targetIdHash = HashUtils.calculateIdHash(methods, targetId);

    // CRITICAL: Target must be DEACTIVATED (expiration == 0), not just expired
    if (_expirationDate[targetIdHash] != 0) {
      revert DidNotDeactivated();
    }

    // Handle self-reactivation vs controller-reactivation differently
    if (senderIdHash == targetIdHash) {
      // Self-reactivation: owner reactivating their own deactivated DID
      // Skip DID expiration check (it's deactivated), but validate VM ownership
      if (!_isVmOwner(senderIdHash, senderVmId, msg.sender)) {
        revert NotAuthenticatedAsSenderId();
      }
    } else {
      // Controller reactivation: another DID is reactivating the target
      // Sender's DID must be active (not expired/deactivated)
      if (_isExpired(senderIdHash)) {
        revert DidExpired();
      }

      // Sender must be authenticated with a valid VM
      if (!_isAuthenticated(senderIdHash, senderVmId, msg.sender)) {
        revert NotAuthenticatedAsSenderId();
      }

      // Sender must be controller of target
      if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
        revert NotAControllerForTargetId();
      }
    }

    // Reactivate: set expiration to 4 years from now
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
    emit DidReactivated(targetIdHash);
  }

  function updateController(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external onlyDirectEOA {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (bytes32 senderIdHash, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    // If controller position is greater than MAX_LENGTH, always overwrite the last controller
    if (controllerPosition > CONTROLLERS_MAX_LENGTH - 1) {
      controllerPosition = CONTROLLERS_MAX_LENGTH - 1;
    }
    // Update the controllers mapping
    _controllers[targetIdHash][controllerPosition] = Controller({ id: controllerId, vmId: controllerVmId });
    // Emit the ControllerUpdated event
    emit ControllerUpdated(senderIdHash, targetIdHash, controllerPosition, controllerVmId);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  function updateService(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes memory type_,
    bytes memory serviceEndpoint
  ) external onlyDirectEOA {
    //* Params validation
    _validateTripleParams(methods, senderId, targetId);
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(methods, senderId, senderVmId, targetId);
    _updateService(targetIdHash, serviceId, type_, serviceEndpoint);
    updateExpiration({ idHash: targetIdHash, forceExpire: false });
  }

  // ═══════════════════════════════════════════════════════════════════
  // Shared auth (IDidAuth — WRITTEN ONCE)
  // ═══════════════════════════════════════════════════════════════════

  function isVmRelationship(bytes32 methods, bytes32 id, bytes32 vmId, bytes1 relationship, address sender)
    public
    view
    returns (bool)
  {
    _validateViewParams(methods, id, sender);
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    // Check if DID is expired/deactivated before checking VM relationship
    if (_isExpired(idHash)) {
      revert DidExpired();
    }
    return _isVmRelationship(idHash, vmId, relationship, sender);
  }

  /// @dev Checks if sender is authorized to act on targetId with the given VM relationship.
  /// Uses _getVmForAuth hook (variant-specific) to retrieve VM fields without depending on struct type.
  /// Non-reverting: returns false for expired DIDs or invalid VMs. Reverts only on invalid inputs.
  /// @param methods The DID methods (bytes32 with three 10-byte segments).
  /// @param senderId The ID of the sender's DID.
  /// @param senderVmId The ID of the sender's Verification Method.
  /// @param targetId The ID of the target DID.
  /// @param relationship The required W3C relationship bitmask (0x01-0x1F).
  /// @param sender The EOA address claiming ownership of the sender VM.
  /// @return True if sender is authorized; false otherwise.
  function isAuthorized(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) external view returns (bool) {
    return _isAuthorized(methods, senderId, senderVmId, targetId, relationship, sender);
  }

  /// @dev Verifies off-chain authorization by recovering the signer from an ECDSA signature
  /// and delegating to _isAuthorized. Non-reverting for auth failures. Reverts only on invalid inputs.
  /// The messageHash is opaque — callers decide the signing scheme (raw, EIP-191, EIP-712).
  /// @param methods The DID methods (bytes32 with three 10-byte segments).
  /// @param senderId The ID of the sender's DID (signer's DID).
  /// @param senderVmId The ID of the sender's Verification Method.
  /// @param targetId The ID of the target DID (may equal senderId for self-owned).
  /// @param relationship The required W3C relationship bitmask (0x01-0x1F).
  /// @param messageHash The hash that was signed (opaque to this function).
  /// @param v ECDSA recovery parameter (27 or 28).
  /// @param r ECDSA signature component r.
  /// @param s ECDSA signature component s.
  /// @return True if the recovered signer is authorized; false otherwise.
  function isAuthorizedOffChain(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    bytes32 messageHash,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external view returns (bool) {
    // Validate signature-specific params (remaining validated by _isAuthorized)
    if (messageHash == bytes32(0) || r == bytes32(0) || s == bytes32(0)) {
      revert MissingRequiredParameter();
    }

    // Recover signer — returns address(0) on invalid signature
    address recovered = ecrecover(messageHash, v, r, s);
    if (recovered == address(0)) return false;

    // Delegate to shared authorization logic
    return _isAuthorized(methods, senderId, senderVmId, targetId, relationship, recovered);
  }

  /// @notice Verifies off-chain authorization for a *claimed* signer, supporting both EOAs and
  /// ERC-1271 smart-contract signers (smart accounts, multisigs, EIP-7702-delegated EOAs).
  /// @dev Unlike {isAuthorizedOffChain}, the signer cannot be recovered from a contract signature,
  /// so the caller states it explicitly and the contract verifies the claim via
  /// OpenZeppelin's `SignatureChecker`: `ecrecover` when `signer` has no code, an
  /// `IERC1271.isValidSignature` staticcall otherwise. Non-reverting for authorization and
  /// signature failures; reverts only on missing parameters. Counterfactual (ERC-6492) wallets
  /// are NOT supported: the signing account must already be deployed.
  /// @dev EIP-7702: a delegated EOA has code, so the ERC-1271 branch is taken and fails when the
  /// delegate does not implement `isValidSignature`. An ECDSA fallback covers that case.
  /// @dev Signature malleability: this path rejects a high-`s` signature (OpenZeppelin `ECDSA`),
  /// whereas the raw-`ecrecover` {isAuthorizedOffChain} accepts it. The two views therefore
  /// disagree on a malleated signature; prefer this one.
  /// @param methods The DID methods (three packed 10-byte segments).
  /// @param senderId The sender's DID identifier.
  /// @param senderVmId The sender's verification method identifier.
  /// @param targetId The DID identifier being acted upon.
  /// @param relationship The required VM relationship bitmask.
  /// @param signer The address claimed to have produced `signature` (EOA or ERC-1271 contract).
  /// @param messageHash The hash that was signed.
  /// @param signature The signature bytes (65-byte ECDSA, or an ERC-1271 wallet-specific blob).
  /// @return True when the signature is valid for `signer` and `signer` is authorized.
  function isAuthorizedOffChainWithSigner(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address signer,
    bytes32 messageHash,
    bytes calldata signature
  ) external view returns (bool) {
    // Validate signature-specific params (remaining validated by _isAuthorized)
    if (signer == address(0) || messageHash == bytes32(0) || signature.length == 0) {
      revert MissingRequiredParameter();
    }

    // EOA -> ecrecover; contract -> IERC1271.isValidSignature. Never reverts on a bad signature.
    if (!SignatureChecker.isValidSignatureNowCalldata(signer, messageHash, signature)) {
      // EIP-7702 fallback. A delegated EOA carries code, so SignatureChecker takes the ERC-1271
      // branch and returns false whenever the delegate does not implement isValidSignature, even
      // though the account's own key produced a perfectly valid signature. Recovering directly
      // restores that path. This grants nothing new: under EIP-7702 the private key keeps full
      // control of the account (it can transact directly and re-delegate at will), so its raw
      // signature is authority the key already holds.
      (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecoverCalldata(messageHash, signature);
      if (err != ECDSA.RecoverError.NoError || recovered != signer) return false;
    }

    // Delegate to shared authorization logic
    return _isAuthorized(methods, senderId, senderVmId, targetId, relationship, signer);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Shared read operations (IDidReadOps — WRITTEN ONCE)
  // ═══════════════════════════════════════════════════════════════════

  function getExpiration(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (uint256 exp) {
    bytes32 idHash = HashUtils.calculateIdHash(methods, id);
    if (vmId != bytes32(0)) {
      return _getExpirationVm(idHash, vmId);
    } else {
      return _expirationDate[idHash];
    }
  }

  function getControllerList(bytes32 methods, bytes32 id)
    external
    view
    returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllers)
  {
    return _controllers[HashUtils.calculateIdHash(methods, id)];
  }

  function getService(bytes32 methods, bytes32 id, bytes32 serviceId, uint8 position)
    external
    view
    returns (Service memory service)
  {
    return _getService(HashUtils.calculateIdHash(methods, id), serviceId, position);
  }

  function getServiceListLength(bytes32 methods, bytes32 id) external view returns (uint8 length) {
    return _getServiceListLength(HashUtils.calculateIdHash(methods, id));
  }

  // ═══════════════════════════════════════════════════════════════════
  // Internal shared logic (absorbed from DidManagerBase)
  // ═══════════════════════════════════════════════════════════════════

  /// @dev Validates sender and target DIDs for authenticated operations.
  /// Changed from private to internal so thin managers can call from createVm().
  function _validateSenderAndTarget(bytes32 methods, bytes32 senderId, bytes32 senderVmId, bytes32 targetId)
    internal
    view
    returns (bytes32 senderIdHash, bytes32 targetIdHash)
  {
    senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    targetIdHash = (senderId == targetId) ? senderIdHash : HashUtils.calculateIdHash(methods, targetId);
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) {
      revert DidExpired();
    }
    if (!_isAuthenticated(senderIdHash, senderVmId, msg.sender)) {
      revert NotAuthenticatedAsSenderId();
    }
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) {
      revert NotAControllerForTargetId();
    }
  }

  /// @dev Updates the expiration timestamp for a DID. If forceExpire is true, sets expiration to 0 (deactivated).
  /// Otherwise, refreshes to EXPIRATION seconds from now (4 years).
  /// @param idHash The hash of the DID to update.
  /// @param forceExpire If true, deactivates the DID by setting expiration to 0.
  function updateExpiration(bytes32 idHash, bool forceExpire) internal {
    _expirationDate[idHash] = forceExpire ? 0 : block.timestamp + EXPIRATION;
  }

  /// @dev Checks if a given ID hash is expired.
  function _isExpired(bytes32 idHash) internal view returns (bool expired) {
    uint256 exp = _expirationDate[idHash];
    return exp == 0 || block.timestamp > exp;
  }

  function _isControllerFor(bytes32 senderDid, bytes32 senderVmId, bytes32 senderIdHash, bytes32 targetIdHash)
    internal
    view
    returns (bool)
  {
    bool controllersIsEmpty = true;
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      Controller storage ctrl = _controllers[targetIdHash][i];
      bytes32 ctrlId = ctrl.id;
      if (ctrlId != bytes32(0)) {
        controllersIsEmpty = false;
        bytes32 ctrlVmId = ctrl.vmId;
        if (ctrlVmId != bytes32(0)) {
          if (ctrlVmId == senderVmId && ctrlId == senderDid) {
            return true;
          }
        } else if (ctrlId == senderDid) {
          return true;
        }
      }
    }
    // If controllers array is empty and sender is the target, return true (controllers not used)
    if (controllersIsEmpty && senderIdHash == targetIdHash) {
      return true;
    }
    return false;
  }

  /// @dev Shared authorization logic used by both isAuthorized and isAuthorizedOffChain.
  /// Non-reverting: returns false for expired DIDs or invalid VMs. Reverts only on invalid inputs.
  function _isAuthorized(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) private view returns (bool) {
    _validateAuthorizedParams(methods, senderId, senderVmId, targetId, relationship, sender);
    if (relationship > bytes1(0x1F)) revert VmRelationshipOutOfRange();

    bytes32 senderIdHash = HashUtils.calculateIdHash(methods, senderId);
    bytes32 targetIdHash = (senderId == targetId) ? senderIdHash : HashUtils.calculateIdHash(methods, targetId);

    // 1. Both DIDs must be active
    if (_isExpired(senderIdHash) || _isExpired(targetIdHash)) return false;

    // 2. Sender's VM has the required relationship (non-reverting via _getVmForAuth)
    (uint256 vmExpiration, address vmEthereumAddress, bytes1 vmRelationships) = _getVmForAuth(senderIdHash, senderVmId);
    if (vmExpiration == 0 || vmExpiration <= block.timestamp) return false;
    if (vmEthereumAddress != sender || (vmRelationships & relationship) != relationship) return false;

    // 3. Sender is controller of target (or IS target for self-controlled)
    if (!_isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash)) return false;

    return true;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Parameter Validation Helpers
  // ═══════════════════════════════════════════════════════════════════

  /**
   * @dev Validates that `methods` can only ever render a W3C-conformant DID string.
   *
   * `methods` is three 10-byte segments plus two tail bytes. Segment 0 becomes the DID
   * `method-name`, segments 1 and 2 become colon-separated groups of the `method-specific-id`.
   * W3C DID Core v1.0 section 3.1 defines `method-char = %x61-7A / DIGIT` and
   * `idchar = ALPHA / DIGIT / "." / "-" / "_" / pct-encoded`; pct-encoding is not accepted here
   * because no method segment needs it and accepting a bare "%" would admit an invalid string.
   *
   * Six rules, each closing a concrete defect:
   * 1. Segment 0 is non-empty, else the string starts `did::` with an empty method-name.
   * 2. Segment 0 uses `[a-z0-9]` only.
   * 3. Segments 1 and 2 use `[a-zA-Z0-9.-_]` only, so a ":" cannot inject a segment and a "#"
   *    cannot inject a DID-URL fragment that makes a parser read a different base DID.
   * 4. Filler appears only as a trailing run. Interior filler is stripped at render time, so
   *    `"l;zpf"` and `"lzpf"` would render identically while hashing differently.
   * 5. The filler byte is exactly ";" (`METHOD_FILLER`); `0x00` padding is rejected for the same
   *    injectivity reason. Use `HashUtils.packMethods` to build a canonical value.
   * 6. Segments are left-packed. Without this, `("lzpf","","test")` and `("lzpf","test","")` both
   *    render `did:lzpf:test:<id>` while hashing differently.
   *
   * Together these make the `methods` -> DID-string mapping injective, so a DID string can be
   * decoded back to exactly one `methods`. Called only from `createDid`, the sole point where
   * `methods` enters storage; every other entry point looks up an existing `idHash` and fails
   * naturally on a value that was never stored.
   *
   * @param methods The packed methods value to validate.
   */
  function _validateMethods(bytes32 methods) internal pure {
    bool previousSegmentEmpty = false;
    for (uint256 segment = 0; segment < 3; segment++) {
      uint256 nameLength = 0;
      bool inFiller = false;
      for (uint256 i = 0; i < 10; i++) {
        bytes1 char = methods[segment * 10 + i];
        if (char == METHOD_FILLER) {
          inFiller = true;
          continue;
        }
        if (char == 0x00) revert MethodPaddingMustBeSemicolon();
        if (inFiller) revert MethodFillerNotTrailing();
        bool legal = (char >= 0x61 && char <= 0x7A) || (char >= 0x30 && char <= 0x39); // a-z 0-9
        if (segment != 0) {
          // idchar additionally allows A-Z, ".", "-" and "_"
          legal = legal || (char >= 0x41 && char <= 0x5A) || char == 0x2E || char == 0x2D || char == 0x5F;
        }
        if (!legal) revert MethodCharInvalid();
        nameLength++;
      }
      if (segment == 0) {
        if (nameLength == 0) revert MethodNameEmpty();
      } else {
        if (previousSegmentEmpty && nameLength != 0) revert MethodSegmentsNotLeftPacked();
        previousSegmentEmpty = nameLength == 0;
      }
    }
    // The two unused tail bytes must also be canonical filler.
    if (methods[30] != METHOD_FILLER || methods[31] != METHOD_FILLER) {
      revert MethodPaddingMustBeSemicolon();
    }
  }

  /// @dev Validates that methods, senderId, and targetId are non-zero.
  function _validateTripleParams(bytes32 methods, bytes32 senderId, bytes32 targetId) internal pure {
    if (methods == bytes32(0) || senderId == bytes32(0) || targetId == bytes32(0)) {
      revert MissingRequiredParameter();
    }
  }

  /// @dev Validates all six parameters for isAuthorized view.
  function _validateAuthorizedParams(
    bytes32 methods,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes1 relationship,
    address sender
  ) internal pure {
    if (
      methods == bytes32(0) || senderId == bytes32(0) || senderVmId == bytes32(0) || targetId == bytes32(0)
        || relationship == bytes1(0) || sender == address(0)
    ) {
      revert MissingRequiredParameter();
    }
  }

  /// @dev Validates methods, id, and sender for view functions.
  function _validateViewParams(bytes32 methods, bytes32 id, address sender) internal pure {
    if (methods == bytes32(0) || id == bytes32(0) || sender == address(0)) {
      revert MissingRequiredParameter();
    }
  }
}
