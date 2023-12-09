import { Signer, ContractMethodArgs, Overrides, Block } from "ethers";
import { ContractName, ENV } from "models/Configuration";
import Deployment from "models/Deployment";
import Storage, { StorageDeployResult } from "models/Storage";
import StorageUpgr, { StorageUpgrDeployResult } from "models/StorageUpgr";

/**
 * Deploys a contract with the specified name using the provided deployer and arguments.
 *
 * @param contractName - The name of the contract to deploy.
 * @param deployer - The deployer's signer.
 * @param args - The arguments to pass to the contract's deployment method.
 * @param overrides - Optional overrides for the deployment transaction.
 * @param save - Optional flag indicating whether to save the deployment information.
 * @param tag - Optional tag to associate with the deployment.
 * @returns The deployment information.
 * @throws Error if no contract is found with the specified name.
 */
export async function deploy(
  contractName: ContractName,
  deployer: Signer,
  args: ContractMethodArgs<any[]>,
  overrides?: Overrides,
  save: boolean = false,
  tag?: string,
) {
  let deployResult: StorageDeployResult | StorageUpgrDeployResult;
  switch (String(contractName)) {
    case "Storage":
      deployResult = await Storage.deployStorage(deployer, args[0], overrides);
      break;
    case "StorageUpgr":
      deployResult = await StorageUpgr.deployStorage(
        deployer,
        args[0],
        overrides,
      );
      break;
    default:
      throw new Error(`❌ 🔎 No contract found with name: ${contractName}`);
  }
  const deployment = await Deployment.fromReceipt(
    contractName,
    deployResult.receipt,
    deployResult.contract.address,
    (deployResult as StorageUpgrDeployResult)
      ? (deployResult as StorageUpgrDeployResult).contract.logicAddress
      : undefined,
    tag,
  );
  if (save) {
    await deployment.toJson();
  }
  return deployment;
}

/**
 * Upgrades a contract with the specified parameters.
 * @param contractName - The name of the contract to upgrade.
 * @param upgrader - The signer account performing the upgrade.
 * @param args - The arguments for the contract method.
 * @param overrides - Optional overrides for the transaction.
 * @param address - The address of the contract to upgrade.
 * @param logic - The logic contract address to upgrade to.
 * @param tag - The tag associated with the deployment.
 * @returns The updated deployment object.
 * @throws If the deployment cannot be retrieved from JSON or if the address or logic is not provided.
 */
export async function upgrade(
  contractName: ContractName,
  upgrader: Signer,
  args: ContractMethodArgs<any[]> = [],
  overrides?: Overrides,
  address?: string,
  logic?: string,
  tag?: string,
) {
  let deployment: Deployment | undefined;
  try {
    deployment = await Deployment.fromJson(
      undefined,
      undefined,
      contractName,
      tag,
    );
  } catch (error) {
    console.error("\x1b[31m❌  🔎  Cannot get deployment from json", error);
  }
  if (!deployment && !address) {
    throw new Error(`\x1b[31m❌ Address not provided and deployment not found`);
  }
  address = address || deployment?.address;
  logic = logic || deployment?.logic;
  if (!address || !logic) {
    throw new Error("\x1b[31m❌ Address or logic not provided");
  }
  let deployResult: StorageUpgrDeployResult;
  let deployBlock: Promise<Block | null>;
  switch (String(contractName)) {
    case "StorageUpgr":
      const storage = new StorageUpgr(address, logic, upgrader);
      deployResult = await storage.upgradeStorage(undefined, overrides);
      deployBlock = ENV.provider.getBlock(deployResult.receipt.blockHash);
      break;
    default:
      throw new Error(`❌ 🔎 No contract found with name: ${contractName}`);
  }
  if (deployment) {
    await deployment.updateLogic(
      deployResult.contract.logicAddress,
      (await deployBlock)!.timestamp,
    );
  } else {
    deployment = await Deployment.fromReceipt(
      contractName,
      deployResult.receipt,
      deployResult.contract.address,
      deployResult.contract.logicAddress,
      tag,
    );
  }
  return deployment;
}

// export const changeLogic = async (
//   proxy: string,
//   newLogic: string,
//   signer: Signer,
//   proxyAdmin?: string,
// ) => {
//   proxyAdmin = proxyAdmin || (await getProxyAdminDeployment(proxy))?.address;
//   if (!proxyAdmin) {
//     throw new Error(`ERROR: ${proxy} NOT found in this network`);
//   }
//   // instanciate the ProxyAdmin
//   const proxyAdminContract = await getContractInstance<ProxyAdmin>(
//     "ProxyAdmin",
//     signer,
//     proxyAdmin,
//   );

//   try {
//     const proxyAdminCode = await signer.provider!.getCode(proxyAdmin);
//     if (keccak256(proxyAdminCode) != PROXY_ADMIN_CODEHASH) {
//       throw new Error(
//         `ERROR: ProxyAdmin(${proxyAdmin}) is not a ProxyAdmin Contract`,
//       );
//     }
//   } catch (error) {
//     throw new Error(
//       `ERROR: ProxyAdmin(${proxyAdmin}) is not a ProxyAdmin Contract`,
//     );
//   }
//   // Get logic|implementation address
//   const previousLogic = proxyAdminContract.getProxyImplementation(proxy);
//   // Change logic contract
//   const receipt = await (
//     await proxyAdminContract.upgrade(proxy, newLogic, GAS_OPT.max)
//   ).wait();
//   // Get logic|implementation address
//   const actualLogic = proxyAdminContract.getProxyImplementation(proxy);

//   return { previousLogic, actualLogic, receipt };
// };
