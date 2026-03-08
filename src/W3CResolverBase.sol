// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IW3CResolver } from "@interfaces/IW3CResolver.sol";
import { W3CDidDocument, W3CVerificationMethod, W3CService, W3CDidInput } from "@types/W3CTypes.sol";
import { IDidReadOps } from "@interfaces/IDidReadOps.sol";
import { W3CResolverUtils } from "@src/W3CResolverUtils.sol";

/// @title W3CResolverBase
/// @author Miguel Gomez Carpena
/// @notice Abstract base for W3C DID document resolvers.
/// Shared: resolve(), resolveService(), _bytesToHexString().
/// Abstract: resolveVm(), _getAllVerificationMethods() — variant-specific VM handling.
abstract contract W3CResolverBase is IW3CResolver {
  IDidReadOps internal _didReadOps;

  function resolve(W3CDidInput memory didInput, bool includeExpired)
    external
    view
    returns (W3CDidDocument memory didDocument)
  {
    W3CResolverUtils.checkDidInput(didInput);
    // * Get Verification Methods (variant-specific)
    (W3CVerificationMethod[] memory vms, string[][] memory methods) =
      _getAllVerificationMethods(didInput, includeExpired);
    // * Get Services
    W3CService[] memory services = new W3CService[](_didReadOps.getServiceListLength(didInput.methods, didInput.id));
    for (uint8 i = 0; i < services.length; i++) {
      services[i] = W3CResolverUtils.toW3cService(
        _didReadOps.getService(
          didInput.methods,
          didInput.id,
          bytes32(0),
          i + 1 // service list starts at 1
        )
      );
    }

    // * Structure DID Document
    string[] memory ctx = new string[](1);
    ctx[0] = "https://www.w3.org/ns/did/v1";
    return W3CDidDocument({
      context: ctx,
      id: W3CResolverUtils.formatDidString(didInput),
      controller: W3CResolverUtils.toW3cController(
        _didReadOps.getControllerList(didInput.methods, didInput.id), didInput.methods
      ),
      verificationMethod: vms,
      authentication: methods[0],
      assertionMethod: methods[1],
      keyAgreement: methods[2],
      capabilityInvocation: methods[3],
      capabilityDelegation: methods[4],
      service: services,
      expiration: _didReadOps.getExpiration(didInput.methods, didInput.id, bytes32(0)) * 1000
    });
  }

  function resolveService(W3CDidInput memory didInput, bytes32 serviceId)
    public
    view
    returns (W3CService memory service)
  {
    W3CResolverUtils.checkDidInput(didInput);
    return W3CResolverUtils.toW3cService(_didReadOps.getService(didInput.methods, didInput.id, serviceId, 0));
  }

  function _bytesToHexString(bytes memory input) internal pure returns (string memory hexString) {
    return W3CResolverUtils.bytesToHexString(input);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Abstract hooks (variant-specific)
  // ═══════════════════════════════════════════════════════════════════

  function _getAllVerificationMethods(W3CDidInput memory didInput, bool includeExpired)
    internal
    view
    virtual
    returns (W3CVerificationMethod[] memory vms, string[][] memory methods);
}
