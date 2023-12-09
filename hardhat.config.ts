import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
// import { ethers } from "hardhat"; //! Cannot be imported here or any file that is imported here because it is generated here
import { HardhatUserConfig } from "hardhat/types";
import { BLOCKCHAIN, KEYSTORE } from "configuration";
import { networkNameToId } from "models/Configuration";
import { quickTest, createSigner, deploy, upgrade } from "tasks/index";

//* TASKS
quickTest;
// WALLET
createSigner;
// DEPLOY
deploy;
upgrade;

//* Config
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
const config: HardhatUserConfig = {
  solidity: {
    version: BLOCKCHAIN.default.solVersion,
    settings: {
      optimizer: {
        enabled: true,
      },
      evmVersion: BLOCKCHAIN.default.evm,
    },
  },
  networks: {
    hardhat: {
      chainId: networkNameToId.hardhat.num,
      blockGasLimit: BLOCKCHAIN.default.gasLimit,
      gasPrice: BLOCKCHAIN.default.gasPrice,
      hardfork: BLOCKCHAIN.default.evm,
      initialBaseFeePerGas: BLOCKCHAIN.default.initialBaseFeePerGas,
      allowUnlimitedContractSize: false,
      accounts: {
        mnemonic: KEYSTORE.default.mnemonic.phrase,
        path: KEYSTORE.default.mnemonic.basePath,
        count: KEYSTORE.default.accountNumber,
        // passphrase: KEYSTORE.default.password,
        accountsBalance: String(
          BigInt(KEYSTORE.default.balance) * BigInt("0x0de0b6b3a7640000"),
        ),
      },
      loggingEnabled: false,
      mining: {
        auto: true,
        interval: [3000, 6000], // if auto is false then randomly generate blocks between 3 and 6 seconds
        mempool: { order: "fifo" }, // [priority] change how transactions/blocks are procesed
      },
    },
    ganache: {
      url: `${BLOCKCHAIN.networks.get(networkNameToId.ganache.bi)
        ?.protocol}://${BLOCKCHAIN.networks.get(networkNameToId.ganache.bi)
        ?.hostname}:${BLOCKCHAIN.networks.get(networkNameToId.ganache.bi)
        ?.port}`,
      chainId: networkNameToId.ganache.num,
      blockGasLimit: BLOCKCHAIN.default.gasLimit,
      gasPrice: BLOCKCHAIN.default.gasPrice,
      hardfork: BLOCKCHAIN.default.evm,
      initialBaseFeePerGas: BLOCKCHAIN.default.initialBaseFeePerGas,
    },
  },
  contractSizer: {
    runOnCompile: true,
  },
  gasReporter: {
    enabled: true,
    currency: "EUR",
  },
  typechain: {
    target: "ethers-v6",
    // externalArtifacts: [
    //   // Not working with byzantium EVM (compile)
    //   "node_modules/@openzeppelin/contracts/build/contracts/ProxyAdmin.json",
    //   "node_modules/@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json",
    // ],
  },
};

export default config;
