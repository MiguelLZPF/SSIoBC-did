// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.33;

import { Script } from "forge-std/Script.sol";
import { Configuration, Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { IDidManagerNative } from "@src/interfaces/IDidManagerNative.sol";
import { W3CResolverNative } from "@src/W3CResolverNative.sol";

/**
 * @title DeployCommand
 * @dev Struct representing a deployment command.
 */
struct DeployCommand {
  DeploymentStoreInfo storeInfo; // Deployment store information.
  IDidManagerNative didManager;
}

contract W3CResolverNativeScript is Script {
  string private constant CONTRACT_NAME = "W3CResolverNative";
  string private constant CONTRACT_FILE_NAME = "W3CResolverNative.sol";
  Configuration config = new Configuration();

  function deploy(IDidManagerNative didManager, bool store, string calldata tag, bool broadcast)
    external
    returns (W3CResolverNative w3cResolverNative, Deployment memory deployment)
  {
    bytes32 tag_ = bytes32(bytes(tag));
    return _deploy(
      DeployCommand({ didManager: didManager, storeInfo: DeploymentStoreInfo({ store: store, tag: tag_ }) }), broadcast
    );
  }

  function _deploy(DeployCommand memory command, bool broadcast)
    internal
    returns (W3CResolverNative w3cResolverNative, Deployment memory deployment)
  {
    // Only thing that is executed in the blockchain
    if (broadcast) {
      vm.startBroadcast();
      w3cResolverNative = new W3CResolverNative(command.didManager);
      vm.stopBroadcast();
    } else {
      w3cResolverNative = new W3CResolverNative(command.didManager);
    }
    // Generate deployment data
    deployment = Deployment({
      bytecodeHash: keccak256(vm.getCode(CONTRACT_FILE_NAME)),
      chainId: block.chainid,
      logicAddr: address(w3cResolverNative),
      name: bytes32(bytes(CONTRACT_NAME)),
      proxyAddr: address(0),
      tag: command.storeInfo.tag,
      timestamp: block.timestamp
    });
    // Store the deployment
    if (command.storeInfo.store) {
      config.storeDeployment(deployment);
    }
    return (w3cResolverNative, deployment);
  }
}
