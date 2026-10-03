// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import { Script, console } from "forge-std/Script.sol";
import { Configuration, Deployment } from "@script/Configuration.s.sol";
import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";
import { IW3CResolver } from "@interfaces/IW3CResolver.sol";
import { W3CDidDocument, W3CDidInput } from "@types/W3CTypes.sol";

/**
 * @title SmokeScript
 * @notice Exercises deployed contracts on a live chain: create a DID, then resolve
 * it and assert the document. Two phases, because the DID id is derived from
 * block.prevrandao and therefore cannot be predicted before the tx is mined; the
 * wrapper reads the id from the DidCreated receipt between the two calls.
 */
contract SmokeScript is Script {
  error SmokeFailed(string what);

  Configuration internal config = new Configuration();

  /// @dev Phase 1. Broadcasts createDid. The wrapper reads topics[1] of the
  /// DidCreated log from the run-latest.json receipt to get the id.
  function createDid(bytes32 random) external {
    Deployment memory d = config.retrieveDeployment(block.chainid, "DidManager");
    vm.startBroadcast();
    IDidWriteOps(d.logicAddr).createDid(bytes32(0), random, bytes32("vm-smoke"));
    vm.stopBroadcast();
    console.logString(string.concat("createDid broadcast to ", vm.toString(d.logicAddr)));
  }

  /// @dev Phase 2. Read-only. Resolves the DID and asserts the document.
  function verify(bytes32 id) external view {
    Deployment memory r = config.retrieveDeployment(block.chainid, "W3CResolver");
    W3CDidDocument memory doc =
      IW3CResolver(r.logicAddr).resolve(W3CDidInput({ methods: bytes32(0), id: id, fragment: bytes32(0) }), false);

    if (bytes(doc.id).length == 0) revert SmokeFailed("document id is empty");
    if (doc.verificationMethod.length == 0) revert SmokeFailed("no verification methods");
    if (doc.authentication.length == 0) revert SmokeFailed("no authentication relationship");
    if (doc.expiration == 0) revert SmokeFailed("expiration is zero");

    console.logString(string.concat("resolved ", doc.id));
    console.logString(string.concat("  verificationMethod  ", vm.toString(doc.verificationMethod.length)));
    console.logString(string.concat("  authentication      ", vm.toString(doc.authentication.length)));
    console.logString(string.concat("  expiration (ms)     ", vm.toString(doc.expiration)));
    console.logString("SMOKE OK");
  }
}
