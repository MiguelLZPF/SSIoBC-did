// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import { Script, console } from "forge-std/Script.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Configuration, Deployment } from "@script/Configuration.s.sol";
import { DidManager } from "@src/DidManager.sol";
import { DidManagerNative } from "@src/DidManagerNative.sol";
import { W3CResolver } from "@src/W3CResolver.sol";
import { W3CResolverNative } from "@src/W3CResolverNative.sol";
import { IDidManagerFull } from "@interfaces/IDidManagerFull.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";

/**
 * @title DeployAllScript
 * @notice Deploys both variants and both resolvers in one broadcast, wiring each
 * resolver to its manager. Replaces four separate invocations that required the
 * manager address to be copied by hand into the resolver call.
 */
contract DeployAllScript is Script {
  Configuration internal config = new Configuration();

  function run()
    external
    returns (
      DidManager didManager,
      W3CResolver w3cResolver,
      DidManagerNative didManagerNative,
      W3CResolverNative w3cResolverNative
    )
  {
    string memory tag = vm.envOr("DEPLOY_TAG", string("DeployAll"));

    vm.startBroadcast();
    didManager = new DidManager();
    w3cResolver = new W3CResolver(IDidManagerFull(address(didManager)));
    didManagerNative = new DidManagerNative();
    w3cResolverNative = new W3CResolverNative(IDidManagerNative(address(didManagerNative)));
    vm.stopBroadcast();

    // The ledger is written only by a real broadcast. A dry run (no --broadcast) or a
    // plain simulation must not record addresses of contracts that were never deployed.
    if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
      _record("DidManager", "DidManager.sol", address(didManager), tag);
      _record("W3CResolver", "W3CResolver.sol", address(w3cResolver), tag);
      _record("DidManagerNative", "DidManagerNative.sol", address(didManagerNative), tag);
      _record("W3CResolverNative", "W3CResolverNative.sol", address(w3cResolverNative), tag);
    } else {
      console.logString("dry run: ledger not written (no --broadcast)");
    }

    (, string memory networkName) = config.getNetwork();
    console.logString(string.concat("deployed to ", networkName, " (chain ", vm.toString(block.chainid), ")"));
    console.logString(string.concat("  DidManager        ", vm.toString(address(didManager))));
    console.logString(string.concat("  W3CResolver       ", vm.toString(address(w3cResolver))));
    console.logString(string.concat("  DidManagerNative  ", vm.toString(address(didManagerNative))));
    console.logString(string.concat("  W3CResolverNative ", vm.toString(address(w3cResolverNative))));
  }

  function _record(string memory name, string memory fileName, address addr, string memory tag) internal {
    config.storeDeployment(
      Deployment({
        bytecodeHash: keccak256(vm.getCode(fileName)),
        chainId: block.chainid,
        logicAddr: addr,
        name: bytes32(bytes(name)),
        proxyAddr: address(0),
        tag: bytes32(bytes(tag)),
        timestamp: block.timestamp
      })
    );
  }
}
