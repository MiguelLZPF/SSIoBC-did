// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 * @title Deployment
 * @dev Struct representing a deployment configuration.
 */
struct Deployment {
  bytes32 bytecodeHash; // Hash of the bytecode for the deployment.
  uint256 chainId; // Chain ID where the deployment will take place.
  address logicAddr; // Address of the logic contract.
  // bytes32 logicDeployTxHash;
  bytes32 name; // Name of the deployment.
  address proxyAddr; // Address of the proxy contract.
  bytes32 tag; // Tag associated with the deployment.
  uint256 timestamp; // Timestamp of the deployment.
}

/**
 * @title DeploymentStoreInfo
 * @dev Struct representing a deploy command.
 * @notice This struct represents a deploy command, which is used to store information about a deployment.
 * It contains a flag indicating whether to store the deployment and a tag associated with the deployment.
 */
struct DeploymentStoreInfo {
  bool store; // Flag indicating whether to store the deployment.
  bytes32 tag; // Tag associated with the deployment.
}

contract Configuration is Script {
  using stdJson for string;

  uint256 PORT = vm.envUint("PORT");
  uint256 CHAIN_ID = vm.envUint("CHAIN_ID");
  string HARDFORK = vm.envString("HARDFORK");
  uint256 ACCOUNT_NUMBER = vm.envUint("ACCOUNT_NUMBER");
  string MNEMONIC = vm.envString("MNEMONIC");
  string ANVIL_CONFIG_OUT = vm.envString("ANVIL_CONFIG_OUT");
  string LAST_DEPLOYMENT_PATH = vm.envString("LAST_DEPLOYMENT_PATH");

  constructor() {}

  /**
   * @dev Stores the deployment information in a JSON file.
   * @param deployment The deployment data to be stored.
   */
  function storeDeployment(Deployment calldata deployment) external {
    // Serialize the deployment
    string memory toBeDeployment = "deployment";
    vm.serializeBytes32(toBeDeployment, "tag", deployment.tag);
    vm.serializeBytes32(toBeDeployment, "name", deployment.name);
    vm.serializeAddress(toBeDeployment, "proxyAddr", deployment.proxyAddr);
    vm.serializeAddress(toBeDeployment, "logicAddr", deployment.logicAddr);
    vm.serializeUint(toBeDeployment, "chainId", deployment.chainId);
    vm.serializeBytes32(toBeDeployment, "timestamp", bytes32(deployment.timestamp));
    string memory serializedDeployment = vm.serializeBytes32(
      toBeDeployment,
      "bytecodeHash",
      deployment.bytecodeHash
    );
    // // Serialize the deployment by tag
    // string memory deploymentByTag = "serDeploymentByTag";
    // string memory serDeploymentByTag = vm.serializeString(
    //   deploymentByTag,
    //   vm.toString(deployment.tag),
    //   serializedDeployment
    // );
    // // Serialize the deployment by network
    // string memory deploymentsByNetwork = "deploymentsByNetwork";
    // string memory serDeploymentsByNetwork = vm.serializeString(
    //   deploymentsByNetwork,
    //   vm.toString(deployment.chainId),
    //   serDeploymentByTag
    // );
    // Write the deployment to the deployments.json file
    vm.writeJson(serializedDeployment, LAST_DEPLOYMENT_PATH);
  }

  /**
   * @dev Retrieves the deployment information.
   * @return deployment The deployment information.
   */
  function retrieveDeployment() external view returns (Deployment memory deployment) {
    // Read the deployments.json file
    string memory serializedDeployments = vm.readFile(LAST_DEPLOYMENT_PATH);
    // Set the filter
    // string memory filter = string(abi.encodePacked(".", vm.toString(chainId), ".", tag));
    // Search for the encoded deployment
    bytes memory encDeployment = serializedDeployments.parseRaw(".");
    // Decode the deployment and return it
    return abi.decode(encDeployment, (Deployment));
  }

  /**
   * @dev Retrieves the network information.
   * @return chainId The chain ID of the network.
   * @return networkName The name of the network.
   */
  function getNetwork() external view returns (uint256 chainId, string memory networkName) {
    chainId = block.chainid;
    networkName = chainId == 31337 ? "anvil" : chainId == 1 ? "mainnet" : chainId == 3
      ? "ropsten"
      : chainId == 4
      ? "rinkeby"
      : chainId == 5
      ? "goerli"
      : chainId == 42
      ? "kovan"
      : chainId == 56
      ? "binance"
      : chainId == 97
      ? "bsc-testnet"
      : chainId == 128
      ? "heco"
      : chainId == 256
      ? "heco-testnet"
      : chainId == 137
      ? "matic"
      : chainId == 80001
      ? "mumbai"
      : chainId == 43114
      ? "avalanche"
      : chainId == 43113
      ? "fuji"
      : chainId == 1666700000
      ? "harmony"
      : chainId == 1666600000
      ? "harmony-testnet"
      : chainId == 42161
      ? "arbitrum"
      : chainId == 421611
      ? "arbitrum-testnet"
      : chainId == 250
      ? "fantom"
      : chainId == 4002
      ? "celo"
      : chainId == 44787
      ? "moonbeam"
      : chainId == 246
      ? "zelcore"
      : chainId == 1287
      ? "moonriver"
      : chainId == 43120
      ? "avalanche-testnet"
      : chainId == 43110
      ? "avax"
      : chainId == 4310
      ? "fuji-testnet"
      : chainId == 5777
      ? "ganache"
      : chainId == 31313
      ? "hardhat"
      : "unknown";

    return (chainId, networkName);
  }
}
