import { TransactionRequest } from "ethers";
import { ContractName } from "models/Configuration";

//* Tasks Interfaces
export interface SignerInformation {
  relativePath?: string;
  password?: string;
  privateKey?: string;
  mnemonicPhrase?: string;
  mnemonicPath?: string;
}

export interface GenerateWallets
  extends Omit<SignerInformation, "relativePath"> {
  type?: string;
  batchSize?: number;
  relativePath?: string;
}

export interface GetWalletInfo {
  relativePath?: string;
  password?: string;
  privateKey?: string;
  mnemonicPhrase?: string;
  mnemonicPath?: string;
  showPrivate?: boolean;
}

export interface GetMnemonic {
  relativePath: string;
  password?: string;
}

//* Deployments
// Deploy with option to deploy upgradeable
export interface Deploy extends SignerInformation {
  contractName: ContractName;
  contractArgs: any;
  txValue: number;
  tag?: string;
}

export interface Upgrade extends Omit<Deploy, "upgradeable"> {
  address?: string;
  logic?: string;
}

export interface CallContract extends SignerInformation {
  contractName: ContractName;
  contractAddress: string;
  functionName: string;
  functionArgs: any;
  artifactPath: string;
}

export interface SignTransaction extends SignerInformation {
  unsignedTx: TransactionRequest;
}

export interface GetLogic {
  proxy: string;
  proxyAdmin?: string;
}

export interface ChangeLogic extends SignerInformation {
  proxy: string;
  proxyAdmin?: string;
  newLogic: string;
}
