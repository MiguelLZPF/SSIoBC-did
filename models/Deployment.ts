import Environment, {
  CONTRACT_NAMES,
  ContractName,
  ENV,
} from "models/Configuration";
import {
  TransactionReceipt,
  ContractTransactionReceipt,
  Provider,
  keccak256,
} from "ethers";
import { BLOCKCHAIN, DEPLOY } from "configuration";
import { readFileSync, writeFileSync } from "fs";

/**
 * Represents deployments of contracts on different networks.
 * @typedef {Record<string, Record<string, Record<string, Deployment>>>} Deployments
 * @property {string} NetworkName - The name of the network.
 * @property {string} ContractName - The name of the contract.
 * @property {string} Tag - The deployment tag.
 * @property {Deployment} Deployment - The deployment details.
 */

/**
 * Represents stored deployments of contracts on different networks.
 * @typedef {Record<string, Record<string, Record<string, DeploymentStored>>>} DeploymentsStored
 * @property {string} NetworkName - The name of the network.
 * @property {string} ContractName - The name of the contract.
 * @property {string} Tag - The deployment tag.
 * @property {DeploymentStored} DeploymentStored - The stored deployment details.
 */

/**
 * Represents the properties of a stored deployment.
 * @interface DeploymentStored
 * @property {ContractName} name - The name of the contract.
 * @property {string} tag - The deployment tag.
 * @property {string} address - The address of the deployment.
 * @property {string} [logic] - The logic address of the deployment.
 * @property {LogicHistory[]} [logicHistory] - The history of logic addresses.
 * @property {Date} timestamp - The timestamp of the deployment.
 * @property {string} transactionHash - The transaction hash of the deployment.
 * @property {string} blockHash - The block hash of the deployment.
 * @property {string} codeHash - The code hash of the deployment.
 * @property {number} chainId - The chain ID of the deployment.
 * @property {boolean} upgradeable - Indicates if the deployment is upgradeable.
 */

/**
 * Represents the properties of a logic history entry.
 * @interface LogicHistory
 * @property {Date} timestamp - The timestamp of the logic history entry.
 * @property {string} logic - The logic address.
 */
type Deployments = Record<string, Record<string, Record<string, Deployment>>>;
type DeploymentsStored = Record<
  string,
  Record<string, Record<string, DeploymentStored>>
>;
interface DeploymentStored {
  name: ContractName;
  tag: string;
  address: string;
  logic?: string;
  logicHistory?: LogicHistory[];
  timestamp: Date;
  transactionHash: string;
  blockHash: string;
  codeHash: string;
  chainId: number;
  upgradeable: boolean;
}
export interface LogicHistory {
  timestamp: Date;
  logic: string;
}

/**
 * Represents a deployment of a smart contract on the Ethereum blockchain.
 * Stores information about the contract's name, address, timestamp, transaction hash, block hash, chain ID, code hash, and other related details.
 * Provides methods for creating, reading, and writing deployments, as well as retrieving transaction and block information.
 */
export default class Deployment {
  name: ContractName;
  address: string;
  timestamp: Date;
  txHash: string;
  blockHash: string;
  chainId: BigInt;
  private _codeHash?: string;
  tag: string;
  provider?: Provider;

  // Ugradeable deployment
  upgradeable: boolean;
  private _logic: LogicHistory[] = [];

  constructor(deployment: Deployment);
  constructor(
    name: ContractName,
    address: string,
    timestamp: Date | number,
    txHash: string,
    blockHash: string,
    chainId: BigInt,
    codeHash?: string,
    tag?: string,
    provider?: Provider,
    logic?: string | LogicHistory[],
  );
  constructor(
    deploymentOrName: ContractName | Deployment,
    address?: string,
    timestamp?: Date | number,
    txHash?: string,
    blockHash?: string,
    chainId?: BigInt,
    codeHash?: string,
    tag?: string,
    provider?: Provider,
    logic?: string | LogicHistory[],
  ) {
    this.name =
      typeof deploymentOrName === "string"
        ? deploymentOrName
        : (deploymentOrName as Deployment).name;
    this.address = address || (deploymentOrName as Deployment).address;
    this.timestamp =
      typeof timestamp === "number"
        ? new Date(timestamp * 1000)
        : timestamp || (deploymentOrName as Deployment).timestamp;
    if (logic && typeof logic === "string") {
      this._logic = new Array<LogicHistory>({
        timestamp: this.timestamp,
        logic: logic,
      });
    } else if (logic) {
      this._logic = logic as LogicHistory[];
    } else {
      this._logic = (deploymentOrName as Deployment)._logic;
    }

    this.txHash = txHash || (deploymentOrName as Deployment).txHash;
    this.blockHash = blockHash || (deploymentOrName as Deployment).blockHash;
    this.chainId = chainId || (deploymentOrName as Deployment).chainId;
    this._codeHash = codeHash || (deploymentOrName as Deployment)._codeHash;
    this.tag = tag || (deploymentOrName as Deployment).tag || "untagged";
    this.provider = provider || (deploymentOrName as Deployment).provider;
    // Set upgradeable flag based on logic
    this._logic ? (this.upgradeable = true) : (this.upgradeable = false);
  }
  //* Static
  /**
   * Creates a new instance of the `Deployment` class based on a transaction receipt.
   * Retrieves the transaction and block information associated with the receipt,
   * and initializes the properties of the new `Deployment` instance.
   * @param name - The name of the contract.
   * @param receipt - The transaction receipt.
   * @param address - The address of the contract (optional).
   * @param logic - The logic of the contract (optional).
   * @param tag - The tag of the contract (optional).
   * @returns A new instance of the `Deployment` class.
   * @throws Error if the transaction or block information is not found.
   */
  static async fromReceipt(
    name: ContractName,
    receipt: ContractTransactionReceipt | TransactionReceipt,
    address?: string,
    logic?: string,
    tag?: string,
  ) {
    const [transaction, block] = await Promise.all([
      ENV.provider.getTransaction(receipt.hash),
      ENV.provider.getBlock(receipt.blockHash),
    ]);
    if (!transaction) {
      throw new Error(`❌ 🔎 could not find transaction ${receipt.hash}`);
    }
    if (!block) {
      throw new Error(`❌ 🔎 could not find transaction ${receipt.blockHash}`);
    }
    return new Deployment(
      name,
      (address || receipt.contractAddress)!,
      block.timestamp,
      transaction.hash,
      block.hash || receipt.blockHash,
      ENV.network.chainId,
      await Deployment.calculateCodeHash(
        (logic || address || receipt.contractAddress)!,
      ),
      tag,
      ENV.provider,
      logic,
    );
  }
  /**
   * Creates a new instance of the Deployment class from a JSON file containing deployment information.
   *
   * @param path - The path to the JSON file containing the deployment information. Defaults to DEPLOY.deploymentsPath if not provided.
   * @param chainId - The chain ID of the network. Defaults to ENV.network.chainId if not provided.
   * @param name - The name of the contract. Defaults to the first contract name in the CONTRACT_NAMES array if not provided.
   * @param tag - The tag of the deployment. Defaults to "untagged" if not provided.
   * @returns A new instance of the Deployment class initialized with the deployment information from the JSON file.
   * @throws An error if the deployment is not found.
   */
  static async fromJson(
    path: string = DEPLOY.deploymentsPath,
    chainId: BigInt = ENV.network.chainId,
    name?: ContractName,
    tag: string = "untagged",
  ) {
    name = (name || CONTRACT_NAMES[0]) as ContractName;
    const deployments = await Deployment.readDeployments(path);
    // Get specific deployment
    const deployment =
      deployments[BLOCKCHAIN.networks.get(chainId)!.name][String(name)][tag];
    if (!deployment) {
      throw new Error(
        `❌ 🔎 Could not find Deployment for network: ${chainId}, ContractName: ${name} and Tag: ${tag}`,
      );
    }
    return new Deployment(deployment);
  }
  /**
   * Reads deployment data from a JSON file and converts it into a structured object.
   *
   * @param path - The file path of the JSON file containing the deployment data. Defaults to DEPLOY.deploymentsPath if not provided.
   * @returns An object containing the deployment data structured by network name, contract name, and tag.
   */
  static async readDeployments(path: string = DEPLOY.deploymentsPath) {
    // Validate the provided path to ensure it is a valid JSON file
    Deployment.validatePath(path);

    let deployments: Deployments = {};

    try {
      // Read the contents of the JSON file
      const fileContents = readFileSync(path, { encoding: "utf8" });

      // Parse the JSON data into a JavaScript object
      const deploymentsFromStorage: DeploymentsStored =
        JSON.parse(fileContents);

      // Convert stored deployments into instances of the Deployment class
      await Deployment.forEachDeployment(
        deploymentsFromStorage,
        (deployment, networkName, contractName) => {
          deployment = deployment as DeploymentStored;

          // Structure the deployments by network name, contract name, and tag
          deployments[networkName] = deployments[networkName] || {};
          deployments[networkName][contractName] =
            deployments[networkName][contractName] || {};
          deployments[networkName][contractName][deployment.tag] =
            new Deployment(
              deployment.name,
              deployment.address,
              deployment.timestamp,
              deployment.transactionHash,
              deployment.blockHash,
              BigInt(deployment.chainId),
              deployment.codeHash,
              deployment.tag,
              undefined,
              deployment.logicHistory || deployment.logic,
            );
        },
      );
    } catch (e) {
      // Handle any errors that occur during the process
      console.error(
        `\x1b[31m Error reading deployments from ${path}. Reinitialiceing deployments file... \x1b[0m`,
      );
    }
    // Return the deployments object
    return deployments;
  }
  /**
   * Writes the deployment information to a JSON file.
   * @param path - The file path where the deployment information will be written. Defaults to DEPLOY.deploymentsPath if not provided.
   * @param deployments - An object containing the deployment information organized by network, contract, and tag.
   * @returns A boolean indicating whether the write operation was successful or not.
   */
  static async writeDeployments(
    path: string = DEPLOY.deploymentsPath,
    deployments: Deployments,
  ): Promise<boolean> {
    try {
      // Validate the file path to ensure it is a valid JSON file
      Deployment.validatePath(path);

      // Initialize an empty object to store the simplified deployment information
      const deploymentsToStore: DeploymentsStored = {};

      // Iterate over each network, contract, and tag in the deployments object
      await Deployment.forEachDeployment(
        deployments,
        async (deployment, networkName, contractName) => {
          deployment = deployment as Deployment;

          // Get the deployment
          deploymentsToStore[networkName] =
            deploymentsToStore[networkName] || {};
          deploymentsToStore[networkName][contractName] =
            deploymentsToStore[networkName][contractName] || {};

          // Translate to simple JSON Object
          deploymentsToStore[networkName][contractName][deployment.tag] = {
            name: deployment.name,
            tag: deployment.tag,
            address: deployment.address,
            logic: deployment._logic?.[deployment._logic.length - 1]?.logic,
            logicHistory: deployment._logic,
            timestamp: deployment.timestamp,
            transactionHash: deployment.txHash,
            blockHash: deployment.blockHash,
            codeHash: await deployment.codeHash(),
            chainId: Number(deployment.chainId),
            upgradeable: deployment.upgradeable,
          };
        },
      );

      // Write the deploymentsToStore object to the specified file path as a JSON string
      writeFileSync(path, JSON.stringify(deploymentsToStore), {
        encoding: "utf8",
      });

      return true;
    } catch (e) {
      return false;
    }
  }
  /**
   * Iterates over a nested object structure representing deployments and calls a callback function for each deployment.
   * @param deployments - A nested object structure representing deployments.
   * @param callback - The callback function to be called for each deployment.
   */
  static async forEachDeployment(
    deployments: Deployments | DeploymentsStored,
    callback: (
      deployment: Deployment | DeploymentStored,
      networkName: string,
      contractName: string,
    ) => void,
  ) {
    for (const networkName in deployments) {
      if (Object.prototype.hasOwnProperty.call(deployments, networkName)) {
        const deploymentsInNetwork = deployments[networkName];
        for (const contractName in deploymentsInNetwork) {
          if (
            Object.prototype.hasOwnProperty.call(
              deploymentsInNetwork,
              contractName,
            )
          ) {
            const deploymentsInName = deploymentsInNetwork[contractName];
            for (const tag in deploymentsInName) {
              if (
                Object.prototype.hasOwnProperty.call(deploymentsInName, tag)
              ) {
                const deployment = deploymentsInName[tag];
                callback(deployment, networkName, contractName);
              }
            }
          }
        }
      }
    }
  }
  /**
   * Calculates the code hash of a given contract address using the keccak256 hash function.
   * @param address - The contract address for which to calculate the code hash.
   * @param provider - (optional) The provider object to use for retrieving the contract code.
   *                    If not provided, the default provider from the ENV object will be used.
   * @returns The calculated code hash of the contract at the given address.
   * @throws Error if the code cannot be found for the given address.
   */
  static async calculateCodeHash(
    address: string,
    provider: Provider = ENV.provider,
  ): Promise<string> {
    const code = await provider.getCode(address);
    if (!code) {
      throw new Error(
        `\x1b[31m❌ 🔎 code cannot be found for ${address}\x1b[0m`,
      );
    }
    return keccak256(code);
  }
  /**
   * Validates the path of a deployment file.
   * @param path - The path of the deployment file.
   * @throws {Error} - If the path is invalid or the file extension is not ".json" or ".jsonc".
   */
  static validatePath(path: string): void {
    const [mainPath, extension] = path.split(".");

    // Check for additional parts in the path
    if (extension === undefined || extension.includes(".")) {
      throw new Error(
        `❌ 🗂️ Invalid deployments path. Use of invalid character "." ${path}`,
      );
    }

    // Add ".json" extension if missing
    if (!extension) {
      path += ".json";
    }

    // Check if the file extension is valid
    if (extension !== "json" && extension !== "jsonc") {
      throw new Error(
        `❌ 🗂️ Deployment file must be a JSON file. File extension: ${extension}`,
      );
    }
  }
  //* Setters
  async toJson(path?: string) {
    const deployments = await Deployment.readDeployments(path);
    // Initialize when needed
    const thisNetworkName = BLOCKCHAIN.networks.get(this.chainId)!.name;
    if (!deployments[thisNetworkName]) {
      deployments[thisNetworkName] = {};
    }
    if (!deployments[thisNetworkName][String(this.name)]) {
      deployments[thisNetworkName][String(this.name)] = {};
    }
    // Set this new deployment
    deployments[thisNetworkName][String(this.name)][this.tag] = this;
    const writed = await Deployment.writeDeployments(path, deployments);
    if (!writed) {
      throw new Error(`❌ 📝 Couldn't write deployment to ${path}`);
    }
  }
  async updateLogic(logic: string, timestamp: Date | number) {
    this._logic.push({
      logic: logic,
      timestamp:
        typeof timestamp === "number" ? new Date(timestamp * 1000) : timestamp,
    });
    await this.toJson();
  }
  //* Getters
  get transactionHash() {
    return this.txHash;
  }
  get networkId() {
    return this.chainId;
  }
  get network() {
    return Environment.getNetwork(this.chainId);
  }
  get proxy() {
    this._checkUpgradeable();
    return this.address;
  }
  get logic() {
    this._checkUpgradeable();
    return this._logic[this._logic.length - 1].logic;
  }
  get implementation() {
    return this.logic;
  }
  get logicHistory() {
    this._checkUpgradeable();
    return this._logic;
  }
  get implementationHistory() {
    return this.logicHistory;
  }
  async getTransaction(provider: Provider | undefined = this.provider) {
    provider = this._checkProvider(provider);
    return provider.getTransaction(this.txHash);
  }
  async getBlock(provider: Provider | undefined = this.provider) {
    provider = this._checkProvider(provider);
    return provider.getBlock(this.blockHash);
  }
  async getReceipt(provider: Provider | undefined = this.provider) {
    provider = this._checkProvider(provider);
    return provider.getTransactionReceipt(this.txHash);
  }
  async codeHash() {
    return this._codeHash || (await this._calculateCodeHash());
  }
  //* Private
  private _checkProvider(provider: Provider | undefined = this.provider) {
    if (!provider) {
      throw new Error(`❌ Provider must be set to perform this operation`);
    }
    return provider;
  }
  private async _calculateCodeHash() {
    this._codeHash = await Deployment.calculateCodeHash(
      this.logic || this.address,
      this.provider,
    );
    return this._codeHash;
  }
  private _checkUpgradeable() {
    if (!this.upgradeable) {
      throw new Error(`❌ This deployment is not upgradeable`);
    }
  }
}
