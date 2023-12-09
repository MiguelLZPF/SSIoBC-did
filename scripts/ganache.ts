import { BLOCKCHAIN, KEYSTORE } from "configuration";
import ganache from "ganache";
import {} from "ethers";
import { networkNameToId } from "models/Configuration";

const GANACHE_NET_ID = networkNameToId.ganache;

const ganacheServer = ganache.server({
  chain: {
    chainId: GANACHE_NET_ID.num,
    hardfork: BLOCKCHAIN.default.evm,
    vmErrorsOnRPCResponse: true,
  },
  miner: {
    blockGasLimit: BLOCKCHAIN.default.gasLimit,
    defaultGasPrice: BLOCKCHAIN.default.gasPrice,
  },
  wallet: {
    mnemonic: KEYSTORE.default.mnemonic.phrase,
    hdPath: KEYSTORE.default.mnemonic.basePath,
    totalAccounts: KEYSTORE.default.accountNumber,
    lock: false,
    passphrase: KEYSTORE.default.password,
    defaultBalance: Number(BigInt(KEYSTORE.default.balance)),
  },
  database: {
    dbPath: BLOCKCHAIN.networks.get(GANACHE_NET_ID.bi)?.dbPath,
  },
  logging: {
    // quiet: true,
    // verbose: true,
  },
});

async function main() {
  try {
    await ganacheServer.listen(
      BLOCKCHAIN.networks.get(GANACHE_NET_ID.bi)!.port,
    );
    console.log(
      `Ganache server listening on port ${BLOCKCHAIN.networks.get(
        GANACHE_NET_ID.bi,
      )?.port}...`,
    );
    const provider = ganacheServer.provider;
    console.log(
      "Chain: ",
      provider.getOptions().chain,
      "Miner: ",
      provider.getOptions().miner,
      "Accounts: ",
      provider.getInitialAccounts(),
    );
  } catch (error) {
    console.log("ERROR: Ganache server error", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
