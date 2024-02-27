// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {StorageUpgr as Storage} from "@src/StorageUpgr.sol";
import {Configuration, Deployment, DeploymentStoreInfo} from "@script/Configuration.s.sol";

//* Reference: https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades

/**
 * @title DeployCommand
 * @dev Struct representing a deployment command.
 */
struct DeployCommand {
  uint256 initValue; // Initial value for the deployment.
  DeploymentStoreInfo storeInfo; // Deployment store information.
}

/**
 * @dev Represents an upgrade command for a proxy contract.
 * @param proxy The address of the proxy contract.
 * @param contractFileName The name of the contract file to be upgraded.
 * @param storeInfo The deployment store information.
 */
struct UpgradeCommand {
  address proxy; // The address of the proxy contract.
  string contractFileName; // The name of the contract file to be used for upgrade.
  DeploymentStoreInfo storeInfo; // Deployment store information.
}

/**
 * @title StorageUpgrScript
 * @dev A script contract for deploying the Storage contract and storing its deployment information.
 */
contract StorageUpgrScript is Script {
  string private constant CONTRACT_NAME = "StorageUpgr";
  string private constant CONTRACT_FILE_NAME = "StorageUpgr.sol";
  Configuration config = new Configuration();

  /**
   * @dev Deploys a new instance of the Storage contract.
   * @param initValue The initial value for the storage.
   * @param store Determines whether to store the deployment information or not.
   * @param tag The tag associated with the deployment.
   * @return storage_ The deployed Storage contract instance.
   * @return deployment The deployment information.
   */
  function deploy(
    uint256 initValue,
    bool store,
    string calldata tag
  ) external returns (Storage storage_, Deployment memory deployment) {
    bytes32 tag_ = bytes32(bytes(tag));
    return
      this.deploy(
        DeployCommand({
          initValue: initValue,
          storeInfo: DeploymentStoreInfo({store: store, tag: tag_})
        })
      );
  }

  /**
   * @dev Deploys the Storage contract and stores its deployment information.
   * @param command The deploy command containing the initial value for the Storage contract.
   * @return storage_ The deployed Storage contract.
   * @return deployment The deployment information of the Storage contract.
   */
  function deploy(
    DeployCommand calldata command
  ) external returns (Storage storage_, Deployment memory deployment) {
    vm.recordLogs();
    // Only thing that is executed in the blockchain
    vm.startBroadcast();
    storage_ = Storage(
      Upgrades.deployUUPSProxy(
        CONTRACT_FILE_NAME,
        abi.encodeCall(Storage.initialize, (command.initValue))
      )
    );
    vm.stopBroadcast();
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the logic|implementation address
    address logic = address(uint160(uint256((entries[0].topics[1]))));
    // Generate deployment data
    deployment = Deployment({
      bytecodeHash: keccak256(vm.getCode(CONTRACT_FILE_NAME)),
      chainId: block.chainid,
      logicAddr: logic,
      name: bytes32(bytes(CONTRACT_NAME)),
      proxyAddr: address(storage_),
      tag: command.storeInfo.tag,
      timestamp: block.timestamp
    });
    // Store the deployment
    if (command.storeInfo.store) {
      config.storeDeployment(deployment);
    }
    return (storage_, deployment);
  }

  /**
   * @dev Upgrades a contract by deploying a new version and updating the proxy.
   *! @dev To use this, use a statefull blockchain non a ephemeral one. (the proxy is not stored in the ephemeral blockchain)
   * @param proxy The address of the proxy contract.
   * @param contractFileName The name of the contract file to be deployed.
   * @param store A boolean indicating whether to store the deployment information.
   * @param tag The tag associated with the deployment.
   * @return storage_ The upgraded storage contract.
   * @return deployment The deployment information.
   */
  function upgrade(
    address proxy,
    string calldata contractFileName,
    bool store,
    string calldata tag
  ) external returns (Storage storage_, Deployment memory deployment) {
    bytes32 tag_ = bytes32(bytes(tag));
    return
      this.upgrade(
        UpgradeCommand({
          proxy: proxy,
          contractFileName: contractFileName,
          storeInfo: DeploymentStoreInfo({store: store, tag: tag_})
        })
      );
  }

  /**
   * @dev Upgrades the storage contract and returns the updated storage and deployment information.
   *! @dev To use this, use a statefull blockchain non a ephemeral one. (the proxy is not stored in the ephemeral blockchain)
   * @param command The upgrade command containing the necessary information.
   * @return storage_ The updated storage contract.
   * @return deployment The updated deployment information.
   */
  function upgrade(
    UpgradeCommand memory command
  ) external returns (Storage storage_, Deployment memory deployment) {
    if (command.storeInfo.store) {
      console.log("Using last stored deployment");
      deployment = config.retrieveDeployment();
      command.proxy = deployment.proxyAddr;
    }
    require(command.proxy != address(0), "StorageUpgrScript: invalid proxy address");
    vm.recordLogs();
    vm.startBroadcast();
    Upgrades.upgradeProxy(command.proxy, command.contractFileName, "");
    vm.stopBroadcast();
    // Get logs from previous transaction
    Vm.Log[] memory entries = vm.getRecordedLogs();
    // Get the logic|implementation address
    address logic = address(uint160(uint256((entries[0].topics[1]))));
    // Set the deployment tag
    bytes32 tag = deployment.tag;
    if (command.storeInfo.tag != bytes32(0)) {
      tag = command.storeInfo.tag;
    }
    // Generate deployment data
    deployment = Deployment({
      bytecodeHash: keccak256(vm.getCode(command.contractFileName)),
      chainId: block.chainid,
      logicAddr: logic,
      name: bytes32(bytes(CONTRACT_NAME)),
      proxyAddr: command.proxy,
      tag: tag,
      timestamp: block.timestamp
    });
    // Store the deployment
    if (command.storeInfo.store) {
      config.storeDeployment(deployment);
    }
    return (storage_, deployment);
  }
}
