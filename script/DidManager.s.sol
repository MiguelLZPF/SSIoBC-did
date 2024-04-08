// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { Configuration, Deployment, DeploymentStoreInfo } from "@script/Configuration.s.sol";
import { DidManager } from "@src/DidManager.sol";

/**
 * @title DeployCommand
 * @dev Struct representing a deployment command.
 */
struct DeployCommand {
  DeploymentStoreInfo storeInfo; // Deployment store information.
}

contract DidManagerScript is Script {
  string private constant CONTRACT_NAME = "DidManager";
  string private constant CONTRACT_FILE_NAME = "DidManager.sol";
  Configuration config = new Configuration();

  function deploy(
    bool store,
    string calldata tag,
    bool broadcast
  ) external returns (DidManager storage_, Deployment memory deployment) {
    bytes32 tag_ = bytes32(bytes(tag));
    return
      this.deploy(
        DeployCommand({ storeInfo: DeploymentStoreInfo({ store: store, tag: tag_ }) }),
        broadcast
      );
  }

  function deploy(
    DeployCommand memory command,
    bool broadcast
  ) external returns (DidManager storage_, Deployment memory deployment) {
    // Only thing that is executed in the blockchain
    if (broadcast) {
      vm.startBroadcast();
      storage_ = new DidManager();
      vm.stopBroadcast();
    } else {
      storage_ = new DidManager();
    }
    // Generate deployment data
    deployment = Deployment({
      bytecodeHash: keccak256(vm.getCode(CONTRACT_FILE_NAME)),
      chainId: block.chainid,
      logicAddr: address(storage_),
      name: bytes32(bytes(CONTRACT_NAME)),
      proxyAddr: address(0),
      tag: command.storeInfo.tag,
      timestamp: block.timestamp
    });
    // Store the deployment
    if (command.storeInfo.store) {
      config.storeDeployment(deployment);
    }
    return (storage_, deployment);
  }
}
