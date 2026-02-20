// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.33;

import { Script, console } from "forge-std/Script.sol";
import { Configuration, Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManagerNative } from "@src/DidManagerNative.sol";

/**
 * @title DeployCommand
 * @dev Struct representing a deployment command.
 */
struct DeployCommand {
  DeploymentStoreInfo storeInfo; // Deployment store information.
}

contract DidManagerNativeScript is Script {
  string private constant CONTRACT_NAME = "DidManagerNative";
  string private constant CONTRACT_FILE_NAME = "DidManagerNative.sol";
  Configuration config = new Configuration();

  function deploy(bool store, string calldata tag, bool broadcast)
    external
    returns (DidManagerNative didManagerNative, Deployment memory deployment)
  {
    bytes32 tag_ = bytes32(bytes(tag));
    return _deploy(DeployCommand({ storeInfo: DeploymentStoreInfo({ store: store, tag: tag_ }) }), broadcast);
  }

  function _deploy(DeployCommand memory command, bool broadcast)
    internal
    returns (DidManagerNative didManagerNative, Deployment memory deployment)
  {
    // Only thing that is executed in the blockchain
    if (broadcast) {
      console.logString("WARN: Broadcasting deployment, make sure to use --broadcast flag");
      vm.startBroadcast();
      didManagerNative = new DidManagerNative();
      vm.stopBroadcast();
    } else {
      console.logString("WARN: Dry-run deployment. The transaction will NOT be executed.");
      didManagerNative = new DidManagerNative();
    }
    // Generate deployment data
    deployment = Deployment({
      bytecodeHash: keccak256(vm.getCode(CONTRACT_FILE_NAME)),
      chainId: block.chainid,
      logicAddr: address(didManagerNative),
      name: bytes32(bytes(CONTRACT_NAME)),
      proxyAddr: address(0),
      tag: command.storeInfo.tag,
      timestamp: block.timestamp
    });
    // Store the deployment
    if (command.storeInfo.store) {
      config.storeDeployment(deployment);
    }
    return (didManagerNative, deployment);
  }
}
