import { subtask, task, types } from "hardhat/config";
import Environment from "models/Configuration";
import { SignerInformation } from "models/Tasks";
import CustomWallet from "models/Wallet";
import { HDNodeWallet } from "ethers";

export const createSigner = subtask(
  "create-signer",
  "Creates new signer from given params",
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
  .setAction(async (args: SignerInformation, hre) => {
    const { provider } = new Environment(hre);
    let wallet: CustomWallet | HDNodeWallet | undefined;
    if (args.privateKey) {
      wallet = new CustomWallet(args.privateKey, provider);
    } else if (args.mnemonicPhrase) {
      wallet = CustomWallet.fromPhrase(
        args.mnemonicPhrase.toLowerCase() === "default"
          ? undefined
          : args.mnemonicPhrase,
        provider,
        args.mnemonicPhrase.toLowerCase() === "default"
          ? undefined
          : args.mnemonicPath,
      );
    } else if (args.relativePath) {
      wallet = CustomWallet.fromEncryptedJsonSync(
        args.relativePath,
        args.password,
      );
    } else {
      throw new Error(
        "❌  Cannot get a wallet from parameters, needed private key or mnemonic or path",
      );
    }
    return wallet;
  });

// task("generate-wallets", "Generates Encryped JSON persistent wallets")
//   .addPositionalParam(
//     "type",
//     "Type of generation [single, batch]",
//     "single",
//     types.string,
//   )
//   .addParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root to store the wallets",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam("password", "Wallet password", undefined, types.string)
//   .addOptionalParam(
//     "entropy",
//     "Wallet entropy for random generation",
//     undefined,
//     types.string,
//   )
//   .addOptionalParam(
//     "privateKey",
//     "Private key to generate wallet from. Hexadecimal String format expected",
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
//   .addOptionalParam(
//     "batchSize",
//     "Number of user wallets to be generated in batch",
//     undefined,
//     types.int,
//   )
//   .setAction(async (args: IGenerateWallets, hre) => {
//     await setGlobalHRE(hre);
//     let wallet: CustomWallet | HDNodeWallet;
//     if (args.type && args.type.toLowerCase() === "batch") {
//       wallet = (await hre.run("create-signer", {
//         mnemonicPhrase: args.mnemonicPhrase,
//         mnemonicPath: args.mnemonicPath || KEYSTORE.default.mnemonic.basePath,
//       } as ISignerInformation)) as HDNodeWallet;
//       for (
//         let index = 0;
//         index < (args.batchSize || KEYSTORE.default.batchSize);
//         index++
//       ) {
//         new CustomWallet(wallet.deriveChild(index).privateKey).storeEncrypted(
//           `${args.relativePath || "default"}_${
//             index < 10 ? `0${index}` : index
//           }`,
//           args.password,
//         );
//       }
//     } else {
//       wallet = await hre.run("create-signer", {
//         privateKey: args.privateKey,
//         mnemonicPhrase: args.mnemonicPhrase,
//         mnemonicPath: args.mnemonicPath,
//       } as ISignerInformation);
//       new CustomWallet(wallet.privateKey).storeEncrypted(
//         args.relativePath || "default",
//         args.password,
//       );
//     }
//   });

// task(
//   "get-wallet-info",
//   "Recover all information from an encrypted wallet or an HD Wallet",
// )
//   .addOptionalPositionalParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root where the encrypted wallet is located",
//     undefined,
//     types.string,
//   )
//   .addOptionalPositionalParam(
//     "password",
//     "Password to decrypt the wallet",
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
//   .addFlag(
//     "showPrivate",
//     "set to true if you want to show the private key and mnemonic phrase",
//   )
//   .setAction(async (args: IGetWalletInfo, hre) => {
//     const wallet: CustomWallet | HDNodeWallet = await hre.run("create-signer", {
//       relativePath: args.relativePath,
//       password: args.password,
//       privateKey: args.privateKey,
//       mnemonicPhrase: args.mnemonicPhrase,
//       mnemonicPath: args.mnemonicPath,
//     } as ISignerInformation);
//     let privateKey = wallet.privateKey;
//     let mnemonicPhrase: string | undefined = undefined;
//     let mnemonicPath: string | null = null;
//     if (wallet instanceof HDNodeWallet) {
//       mnemonicPhrase = wallet.mnemonic?.phrase;
//       mnemonicPath = wallet.path;
//     }
//     // needed because is read-only
//     if (!args.showPrivate) {
//       privateKey = "***********";
//       mnemonicPhrase = "***********";
//     }
//     console.log(`
//     Wallet information:
//       - Address: ${wallet.address}
//       - Public Key: ${new SigningKey(wallet.privateKey).publicKey}
//       - Private Key: ${privateKey}
//       - Mnemonic:
//         - Phrase: ${mnemonicPhrase}
//         - Path: ${mnemonicPath}
//       - ETH Balance (Wei): ${await hre.ethers.provider.getBalance(
//         wallet.address,
//       )}
//     `);
//   });

// task("get-mnemonic", "Recover mnemonic phrase from an encrypted wallet")
//   .addPositionalParam(
//     "relativePath",
//     "Path relative to KEYSTORE.root where the encrypted wallet is located",
//     undefined,
//     types.string,
//   )
//   .addOptionalPositionalParam(
//     "password",
//     "Password to decrypt the wallet",
//     undefined,
//     types.string,
//   )
//   .setAction(async (args: IGetMnemonic, hre) => {
//     const wallet: HDNodeWallet = await hre.run("create-signer", {
//       relativePath: args.relativePath,
//       password: args.password,
//     } as ISignerInformation);
//     console.log(`
//       - Mnemonic:
//         - Phrase: ${wallet.mnemonic?.phrase}
//         - Path: ${wallet.path}
//     `);
//   });
