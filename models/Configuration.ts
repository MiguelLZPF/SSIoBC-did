import { HardhatUpgrades } from "@openzeppelin/hardhat-upgrades";
import { BLOCKCHAIN } from "configuration";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export type PromiseOrValue<T> = Promise<T> | T;
export type Hardfork = "london" | "berlin" | "byzantium";
export type NetworkProtocol = "http" | "https" | "ws";

// Project contract names allowed
export const CONTRACT_NAMES = ["Storage", "StorageUpgr"] as const;
export type ContractName = typeof CONTRACT_NAMES;

export type NetworkName = "hardhat" | "ganache" | "mainTest"; // you can add whatever Network name here
export interface Network {
  chainId: BigInt;
  name: NetworkName;
  protocol: NetworkProtocol;
  hostname: string;
  port: number;
  dbPath?: string;
}

export const networkNameToId: Record<NetworkName, { bi: BigInt; num: number }> =
  {
    hardhat: { bi: BigInt(31337), num: 31337 },
    ganache: { bi: BigInt(1337), num: 1337 },
    mainTest: { bi: BigInt(1666), num: 1666 },
  };

export let ENV: Environment;

export default class Environment {
  hre: HardhatRuntimeEnvironment;
  ethers: HardhatRuntimeEnvironment["ethers"];
  provider: HardhatRuntimeEnvironment["ethers"]["provider"];
  network: Network;
  upgrades: HardhatUpgrades;

  constructor(hre: HardhatRuntimeEnvironment) {
    this.hre = hre;
    this.ethers = hre.ethers;
    this.provider = hre.ethers.provider;
    this.network = Environment.getNetwork(hre.network.config.chainId);
    this.upgrades = hre.upgrades;
    ENV = this;
  }

  static getNetwork(chainId: BigInt | number = 0) {
    if (typeof chainId === "number" && isNaN(chainId)) {
      chainId = BigInt(0);
    } else if (typeof chainId === "number") {
      chainId = BigInt(chainId);
    }
    const network = BLOCKCHAIN.networks.get(chainId);
    if (!network) {
      throw new Error(
        `Network ${chainId} not found. Please define it in the configuration.ts file`,
      );
    }
    return network;
  }
}
