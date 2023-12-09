import { task, types } from "hardhat/config";
import { GAS_OPT } from "configuration";
import Environment from "models/Configuration";
import * as TaskParams from "models/Tasks";
import * as Scripts from "scripts/deploy";
import CustomWallet from "models/Wallet";
import JSON5 from "json5";
import { HDNodeWallet } from "ethers";

export const deploy = task("deploy", "Deploy smart contracts on '--network'")
  .addPositionalParam(
    "contractName",
    "Name of the contract to deploy (main use: get factory)",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "contractArgs",
    "(Optional) [undefined] Contract initialize function's arguments if any",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "tag",
    "(Optional) [undefined] string to include metadata or anything related with a deployment",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "txValue",
    "Contract creation transaction value if any",
    undefined,
    types.int,
  )
  // Signer params
  .addOptionalParam(
    "relativePath",
    "Path relative to KEYSTORE.root to store the wallets",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "password",
    "Password to decrypt the wallet",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "privateKey",
    "A private key in hexadecimal can be used to sign",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "mnemonicPhrase",
    "Mnemonic phrase to generate wallet from",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "mnemonicPath",
    "Mnemonic path to generate wallet from",
    undefined,
    types.string,
  )
  .setAction(async (args: TaskParams.Deploy, hre) => {
    console.log(
      "\x1b[33m ❗️ WARNING: Remember to compile contracts if needed\x1b[0m",
    );
    const env = new Environment(hre);
    const deployer = (await hre.run("create-signer", {
      relativePath: args.relativePath,
      password: args.password,
      privateKey: args.privateKey,
      mnemonicPhrase: args.mnemonicPhrase,
      mnemonicPath: args.mnemonicPath,
    } as TaskParams.SignerInformation)) as CustomWallet | HDNodeWallet;
    const result = await Scripts.deploy(
      args.contractName,
      deployer,
      args.contractArgs ? JSON5.parse(args.contractArgs as string) : [],
      {
        ...GAS_OPT.max,
        value: args.txValue,
      },
      true,
      args.tag,
    );
    //* Print Result on screen
    console.info(
      "\n✅ 🎉 \x1b[32mContract deployed successfully!\x1b[0m Contract Information:",
      `\n  - Contract Name (id within this project): ${result.name}`,
      `\n  - Contract Address (proxy address if upgradeable deployment): ${result.address}`,
      result.upgradeable
        ? `\n  - Logic | Implementation Address (only if upgradeable deployment): ${result.logic}`
        : "",
      `\n  - Admin or Deployer: ${deployer.address}`,
      `\n  - Deploy Timestamp: ${result.timestamp}`,
      `\n  - Bytecode Hash: ${await result.codeHash()}`,
      `\n  - Tag: ${result.tag}`,
    );
  });

export const upgrade = task(
  "upgrade",
  "Upgrade a deployed smart contracts on '--network'",
)
  .addPositionalParam(
    "contractName",
    "Name of the contract to upgrade (main use: get factory)",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "address",
    "(Optional) [undefined] Contract address or proxy address",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "logic",
    "(Optional) [undefined] Contract logic address or implementation address",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "contractArgs",
    "(Optional) [undefined] Contract initialize function's arguments if any",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "tag",
    "(Optional) [undefined] string to include metadata or anything related with a deployment",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "txValue",
    "Contract creation transaction value if any",
    undefined,
    types.int,
  )
  // Signer params
  .addOptionalParam(
    "relativePath",
    "Path relative to KEYSTORE.root to store the wallets",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "password",
    "Password to decrypt the wallet",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "privateKey",
    "A private key in hexadecimal can be used to sign",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "mnemonicPhrase",
    "Mnemonic phrase to generate wallet from",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "mnemonicPath",
    "Mnemonic path to generate wallet from",
    undefined,
    types.string,
  )
  .setAction(async (args: TaskParams.Upgrade, hre) => {
    console.log(
      "\x1b[33m ❗️ WARNING: Remember to compile contracts if needed\x1b[0m",
    );
    const env = new Environment(hre);
    const upgrader = (await hre.run("create-signer", {
      relativePath: args.relativePath,
      password: args.password,
      privateKey: args.privateKey,
      mnemonicPhrase: args.mnemonicPhrase,
      mnemonicPath: args.mnemonicPath,
    } as TaskParams.SignerInformation)) as CustomWallet | HDNodeWallet;
    const result = await Scripts.upgrade(
      args.contractName,
      upgrader,
      args.contractArgs ? JSON5.parse(args.contractArgs as string) : [],
      {
        ...GAS_OPT.max,
        value: args.txValue,
      },
      args.address,
      args.logic,
      args.tag,
    );
    //* Print Result on screen
    console.info(
      "\n✅ 🎉 \x1b[32mContract upgraded successfully!\x1b[0m Contract Information:",
      `\n  - Contract Name (id within this project): ${result.name}`,
      `\n  - Contract Address (proxy address if upgradeable deployment): ${result.address}`,
      result.upgradeable
        ? `\n  - Logic | Implementation Address (only if upgradeable deployment): ${result.logic}`
        : "",
      `\n  - Admin or Deployer: ${upgrader.address}`,
      `\n  - Deploy Timestamp: ${result.timestamp}`,
      `\n  - Bytecode Hash: ${await result.codeHash()}`,
      `\n  - Tag: ${result.tag}`,
    );
  });

// task(
//   "call-contract",
//   "Call a contract function (this does not change contract storage or state)",
// )
//   .addPositionalParam(
//     "contractName",
//     "the name of the contract to get the ABI",
//     undefined,
//     types.string,
//   )
//   .addPositionalParam(
//     "contractAddress",
//     "the address where de contract is located",
//     undefined,
//     types.string,
//   )
//   .addPositionalParam(
//     "functionName",
//     "the name of the function to call",
//     undefined,
//     types.string,
//   )
//   .addOptionalPositionalParam(
//     "functionArgs",
//     "the arguments to pass to the function",
//     undefined,
//     types.string,
//   )
//   // Signer params
//   .addOptionalParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root to store the wallets",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "password",
//     "Password to decrypt the wallet",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "privateKey",
//     "A private key in hexadecimal can be used to sign",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPhrase",
//     "Mnemonic phrase to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPath",
//     "Mnemonic path to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .setAction(async (args: ICallContract, hre) => {
//     setGlobalHRE(hre);
//     const wallet = await hre.run("create-signer", {
//       relativePath: args.relativePath,
//       password: args.password,
//       privateKey: args.privateKey,
//       mnemonicPhrase: args.mnemonicPhrase,
//       mnemonicPath: args.mnemonicPath,
//     } as ISignerInformation);
//     console.log(
//       `Calling Smart Contract ${args.contractName}.${args.functionName}(${args.functionArgs}) at ${args.contractAddress}...`,
//     );
//     const functionArgs = args.functionArgs
//       ? JSON5.parse(args.functionArgs)
//       : [];
//     const contract = await getContractInstance<Contract>(
//       args.contractName,
//       wallet,
//       args.contractAddress,
//     );
//     console.log(
//       "Result: ",
//       await contract[args.functionName].staticCallResult(...functionArgs),
//     );
//   });

// task(
//   "execute-contract",
//   "Execute the transacction of a contract function (it CHANGES contract storage or state)",
// )
//   .addPositionalParam(
//     "contractName",
//     "the name of the contract to get the ABI",
//     undefined,
//     types.string,
//   )
//   .addPositionalParam(
//     "contractAddress",
//     "the address where de contract is located",
//     undefined,
//     types.string,
//   )
//   .addPositionalParam(
//     "functionName",
//     "the name of the function to call",
//     undefined,
//     types.string,
//   )
//   .addOptionalPositionalParam(
//     "functionArgs",
//     "the arguments to pass to the function",
//     undefined,
//     types.string,
//   )
//   // Signer params
//   .addOptionalParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root to store the wallets",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "password",
//     "Password to decrypt the wallet",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "privateKey",
//     "A private key in hexadecimal can be used to sign",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPhrase",
//     "Mnemonic phrase to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPath",
//     "Mnemonic path to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .setAction(async (args: ICallContract, hre) => {
//     setGlobalHRE(hre);
//     const wallet: Wallet = await hre.run("create-signer", {
//       relativePath: args.relativePath,
//       password: args.password,
//       privateKey: args.privateKey,
//       mnemonicPhrase: args.mnemonicPhrase,
//       mnemonicPath: args.mnemonicPath,
//     } as ISignerInformation);
//     console.log(
//       `Calling Smart Contract ${args.contractName}.${args.functionName}(${args.functionArgs}) at ${args.contractAddress}...`,
//     );
//     const functionArgs = args.functionArgs
//       ? JSON5.parse(args.functionArgs)
//       : [];
//     const contract = await getContractInstance(
//       args.contractName,
//       wallet,
//       args.contractAddress,
//     );
//     const receipt = await (
//       (await contract[args.functionName](
//         ...functionArgs,
//         GAS_OPT.max,
//       )) as ContractTransactionResponse
//     ).wait();
//     if (!receipt) {
//       throw new Error(`❌  ⛓️  Cannot execute transaction. No receipt found`);
//     }
//     console.log("\nTransaction executed succesfully: ", {
//       TransactionHash: receipt.hash,
//       BlockHash: receipt.blockHash,
//       BlockNumber: receipt.blockNumber,
//     });
//   });

// task("sign-tx", "Signs the unsigned transaction")
//   .addPositionalParam(
//     "unsignedTx",
//     "The complete unsigned transaction",
//     undefined,
//     types.string,
//   )
//   // Signer params
//   .addOptionalParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root to store the wallets",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "password",
//     "Password to decrypt the wallet",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "privateKey",
//     "A private key in hexadecimal can be used to sign",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPhrase",
//     "Mnemonic phrase to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPath",
//     "Mnemonic path to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .setAction(async (args: ISignTransaction, hre) => {
//     setGlobalHRE(hre);
//     const wallet: Wallet = await hre.run("create-signer", {
//       relativePath: args.relativePath,
//       password: args.password,
//       privateKey: args.privateKey,
//       mnemonicPhrase: args.mnemonicPhrase,
//       mnemonicPath: args.mnemonicPath,
//     } as ISignerInformation);

//     const signedTx = await wallet.signTransaction(args.unsignedTx);

//     console.log("\nTransaction signed succesfully: ", {
//       UnsignedTransaction: args.unsignedTx,
//       SignedTransaction: signedTx,
//       Signer: wallet.address,
//       SignerNonce: await wallet.getNonce(),
//     });
//   });

// task(
//   "get-logic",
//   "Check what logic|implementation smart contract address is currently using a given proxy",
// )
//   .addPositionalParam(
//     "proxy",
//     "address of the proxy|storage contract",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "proxyAdmin",
//     "Address of a deloyed Proxy Admin",
//     undefined,
//     types.string,
//   )
//   .setAction(async (args: IGetLogic, hre: HardhatRuntimeEnvironment) => {
//     await setGlobalHRE(hre);

//     const { logicFromProxy, adminFromProxy, logicFromAdmin, adminFromAdmin } =
//       await getLogic(args.proxy, args.proxyAdmin);

//     console.log(`
//           Logic contract information:
//             - Logic (from Proxy's storage): ${logicFromProxy}
//             - Admin (from Proxy's storage): ${adminFromProxy}
//             - Logic (from Admin): ${logicFromAdmin}
//             - Admin (from Admin): ${adminFromAdmin}
//         `);
//   });

// task(
//   "change-logic",
//   "change the actual logic|implementation smart contract of a TUP proxy",
// )
//   .addPositionalParam(
//     "proxy",
//     "address of the proxy|storage contract",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "proxyAdmin",
//     "Address of a deloyed Proxy Admin",
//     undefined,
//     types.string,
//   )
//   .addParam(
//     "newLogic",
//     "Address of the new logic|implementation contract",
//     undefined,
//     types.string,
//   )
//   // Signer params
//   .addOptionalParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root to store the wallets",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "password",
//     "Password to decrypt the wallet",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "privateKey",
//     "A private key in hexadecimal can be used to sign",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPhrase",
//     "Mnemonic phrase to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "mnemonicPath",
//     "Mnemonic path to generate wallet from",
//     undefined,
//     types.string,
//   )
//   .setAction(async (args: IChangeLogic, hre: HardhatRuntimeEnvironment) => {
//     setGlobalHRE(hre);
//     const wallet = await hre.run("create-signer", {
//       relativePath: args.relativePath,
//       password: args.password,
//       privateKey: args.privateKey,
//       mnemonicPhrase: args.mnemonicPhrase,
//       mnemonicPath: args.mnemonicPath,
//     } as ISignerInformation);
//     const { previousLogic, actualLogic, receipt } = await changeLogic(
//       args.proxy,
//       args.newLogic,
//       wallet!,
//       args.proxyAdmin,
//     );
//     if (!receipt) {
//       throw new Error(`❌  ⛓️  Cannot execute transaction. No receipt found`);
//     }
//     console.log(`
//           Logic changed successfully:
//             - Previous Logic: ${previousLogic}
//             - Actual Logic: ${actualLogic}
//             - Transaction: ${receipt.hash}
//             - Block: ${receipt.blockHash}
//         `);
//   });
