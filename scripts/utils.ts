import {
  Contract,
  BaseContract,
  TransactionReceipt,
  Provider,
  BlockTag,
  isAddress,
} from "ethers";
import { existsSync, mkdirSync } from "fs";
import { ENV } from "models/Configuration";
import util from "util";

/**
 * Gets the deployed contract timestamp
 * @param contract contract instance to use
 * @param deployTxHash (optional | undefined) it can be used to retrive timestamp
 * @param hre (optional | ghre) use custom HRE
 * @returns ISO string date time representation of the contract timestamp
 */
export const getContractTimestamp = async (
  contract: BaseContract | Contract,
  deployTxHash?: string,
) => {
  let provider = contract.runner?.provider
    ? contract.runner.provider
    : ENV.provider;
  let receipt: TransactionReceipt | null;
  if (
    contract.deploymentTransaction() &&
    contract.deploymentTransaction()!.hash
  ) {
    receipt = await provider.getTransactionReceipt(
      contract.deploymentTransaction()!.hash,
    );
  } else if (deployTxHash && isAddress(deployTxHash)) {
    receipt = await provider.getTransactionReceipt(deployTxHash);
  } else {
    console.error("❌  🔎  Cannot get Tx from contract or parameter");
    return undefined;
  }
  if (receipt && receipt.blockHash) {
    const timestampSeconds = (await provider.getBlock(receipt.blockHash))!
      .timestamp;
    return new Date(timestampSeconds * 1000).toISOString();
  } else {
    console.error("❌  ⛓️  Cannot get Tx Block Hash");
    return undefined;
  }
};

/**
 * Check if directories are present, if they aren't, create them
 * @param reqPath path to extract directories and check them
 */
export const checkDirectoriesInPath = (reqPath: string) => {
  // get all directories to be checked, including keystore root
  const splitPath = reqPath.split("/");
  let directories: string[] = [splitPath[0]];
  for (let i = 1; i < splitPath.length - 1; i++) {
    directories.push(directories[i - 1] + "/" + splitPath[i]);
  }
  checkDirectories(directories);
};

/**
 * Check if directories are present, if they aren't, create them
 * @param reqDirectories Required directories tree in hierarchical order
 */
export const checkDirectories = (reqDirectories: string[]) => {
  for (const directory of reqDirectories) {
    if (!existsSync(directory)) {
      mkdirSync(directory);
    }
  }
};

/**
 *
 * @param block (optional) [latest] block number or hash that reference the block to get the timestamp
 * @param provider (optional) [gProvider] the provider to use
 * @returns the timestamp in seconds
 */
export const getTimeStamp = async (
  block?: BlockTag,
  provider: Provider = ENV.provider,
) => {
  return (await provider.getBlock(block || "latest"))?.timestamp;
};

/**
 * Logs a Typescript object
 * @param object typescript object to be logged
 */
export const logObject = (object: any) => {
  return util.inspect(object, { showHidden: false, depth: null });
};

/**
 * Wait a number of miliseconds and then continues
 * @param ms number os miliseconds to wait for
 * @returns a promise that resolves when the wait is complete
 */
export function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Checks if an object is empty.
 * An object is considered empty if it has no enumerable properties.
 *
 * @param obj - The object to be checked for emptiness.
 * @returns `true` if the object is empty, `false` otherwise.
 *
 * @example
 * const emptyObject = {};
 * const nonEmptyObject = { key: 'value' };
 *
 * console.log(isObjectEmpty(emptyObject)); // Output: true
 * console.log(isObjectEmpty(nonEmptyObject)); // Output: false
 */
export function isObjectEmpty(obj: object): boolean {
  return Object.keys(obj).length === 0;
}
