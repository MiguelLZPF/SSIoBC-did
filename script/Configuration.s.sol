// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import { Helper } from "@script/Helper.sol";

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

contract Configuration is Script, Helper {
  using stdJson for string;

  uint256 PORT = vm.envUint("PORT");
  uint256 CHAIN_ID = vm.envUint("CHAIN_ID");
  string HARDFORK = vm.envString("HARDFORK");
  uint256 ACCOUNT_NUMBER = vm.envUint("ACCOUNT_NUMBER");
  string MNEMONIC = vm.envString("MNEMONIC");
  string ANVIL_CONFIG_OUT = vm.envString("ANVIL_CONFIG_OUT");
  string DEPLOYMENTS_PATH = vm.envString("DEPLOYMENTS_PATH");

  constructor() {}

  /**
   * @dev Stores the deployment information in a JSON file.
   * @param deployment The deployment data to be stored.
   */
  function storeDeployment(Deployment calldata deployment) external {
    // Serialize the deployment
    string memory toBeDeployment = "deployment";
    vm.serializeString(toBeDeployment, "tag", string(_trimBytes(abi.encodePacked(deployment.tag))));
    vm.serializeString(
      toBeDeployment,
      "name",
      string(_trimBytes(abi.encodePacked(deployment.name)))
    );
    vm.serializeAddress(toBeDeployment, "proxyAddr", deployment.proxyAddr);
    vm.serializeAddress(toBeDeployment, "logicAddr", deployment.logicAddr);
    vm.serializeUint(toBeDeployment, "chainId", deployment.chainId);
    vm.serializeUint(toBeDeployment, "timestamp", deployment.timestamp);
    string memory serializedDeployment = vm.serializeBytes32(
      toBeDeployment,
      "bytecodeHash",
      deployment.bytecodeHash
    );

    // Read the existing deployments
    string memory existingDeployments = vm.readFile(DEPLOYMENTS_PATH);

    // Prepare the new deployments list
    string memory newDeployments;

    if (bytes(existingDeployments).length > 0) {
      // Trim the surrounding brackets from the existing deployments
      string memory trimmedExistingDeployments = _trimBrackets(existingDeployments);

      // Insert the new deployment at the beginning and add brackets around the whole array
      newDeployments = string(
        abi.encodePacked("[", serializedDeployment, ",", trimmedExistingDeployments, "]")
      );
    } else {
      // If no existing deployments, create a new array with only the new deployment
      newDeployments = string(abi.encodePacked("[", serializedDeployment, "]"));
    }

    // Write the updated deployments list to the JSON file
    vm.writeJson(newDeployments, DEPLOYMENTS_PATH);
  }

  /**
   * @dev Retrieves the deployment information.
   * @return deployment The deployment information.
   */
  function retrieveDeployment() external view returns (Deployment memory deployment) {
    // Read the deployments.json file
    string memory serializedDeployments = vm.readFile(DEPLOYMENTS_PATH);
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
