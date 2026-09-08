// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
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

  /// @dev Raised by retrieveDeployment when no entry exists for the given chain and name.
  error DeploymentNotFound(uint256 chainId, string name);

  /// @dev Label for the target network, supplied by networks/<name>.env.
  /// Falls back to "chain-<id>" so a new chain needs no code change.
  string NETWORK_NAME = vm.envOr("NETWORK_NAME", string(""));
  string DEPLOYMENTS_PATH = vm.envOr("DEPLOYMENTS_PATH", string(".deployments.json"));

  constructor() { }

  /**
   * @dev Stores the deployment under .[chainId][name], replacing any previous entry.
   * @notice The ledger was an append-only array, so every redeploy on a persistent
   * development chain grew the file and the reader had to scan top-down to guess
   * the current address. Keyed by chain and contract name, a redeploy replaces.
   * @param deployment The deployment data to be stored.
   */
  function storeDeployment(Deployment calldata deployment) external {
    string memory chainKey = vm.toString(deployment.chainId);
    string memory nameKey = string(_trimBytes(abi.encodePacked(deployment.name)));

    string memory obj = "deployment";
    vm.serializeAddress(obj, "address", deployment.logicAddr);
    vm.serializeAddress(obj, "proxyAddress", deployment.proxyAddr);
    vm.serializeBytes32(obj, "bytecodeHash", deployment.bytecodeHash);
    vm.serializeString(obj, "tag", string(_trimBytes(abi.encodePacked(deployment.tag))));
    vm.serializeString(obj, "networkName", NETWORK_NAME);
    string memory serialized = vm.serializeUint(obj, "timestamp", deployment.timestamp);

    // vm.writeJson cannot create an intermediate object, so ensure .[chainId] exists.
    string memory existing = vm.readFile(DEPLOYMENTS_PATH);
    if (bytes(existing).length == 0) {
      vm.writeFile(DEPLOYMENTS_PATH, "{}");
      existing = "{}";
    }
    if (!vm.keyExistsJson(existing, string.concat(".", chainKey))) {
      vm.writeJson("{}", DEPLOYMENTS_PATH, string.concat(".", chainKey));
    }
    vm.writeJson(serialized, DEPLOYMENTS_PATH, string.concat(".", chainKey, ".", nameKey));
  }

  /**
   * @dev Retrieves one deployment by chain and contract name.
   * @notice The previous implementation parsed "." of a JSON array and decoded it
   * into a single struct, which could not work.
   * @param chainId The chain the deployment is on.
   * @param name The contract name, e.g. "DidManager".
   * @return deployment The stored deployment.
   */
  function retrieveDeployment(uint256 chainId, string memory name)
    external
    view
    returns (Deployment memory deployment)
  {
    string memory raw = vm.readFile(DEPLOYMENTS_PATH);
    string memory key = string.concat(".", vm.toString(chainId), ".", name);
    if (!vm.keyExistsJson(raw, key)) revert DeploymentNotFound(chainId, name);

    deployment.chainId = chainId;
    deployment.name = bytes32(bytes(name));
    deployment.logicAddr = raw.readAddress(string.concat(key, ".address"));
    deployment.proxyAddr = raw.readAddress(string.concat(key, ".proxyAddress"));
    deployment.bytecodeHash = raw.readBytes32(string.concat(key, ".bytecodeHash"));
    deployment.tag = bytes32(bytes(raw.readString(string.concat(key, ".tag"))));
    deployment.timestamp = raw.readUint(string.concat(key, ".timestamp"));
  }

  /**
   * @dev Retrieves the network information.
   * @notice The name comes from the NETWORK_NAME environment variable, set by
   * the selected networks/<name>.env profile. The previous implementation was a
   * thirty-deep chain-ID ternary that had to be edited to learn any new chain
   * and was wrong for several of the ones it did list.
   * @return chainId The chain ID of the network.
   * @return networkName The name of the network.
   */
  function getNetwork() external view returns (uint256 chainId, string memory networkName) {
    chainId = block.chainid;
    networkName = bytes(NETWORK_NAME).length > 0 ? NETWORK_NAME : string.concat("chain-", vm.toString(chainId));
    return (chainId, networkName);
  }
}
