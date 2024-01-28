import { KEYSTORE, TEST } from "configuration";
import hre from "hardhat";
import { step } from "mocha-steps";
import { expect } from "chai";
import { Provider, Block, ZeroAddress, isAddress } from "ethers";
import CustomWallet from "models/Wallet";
import DidManager from "models/contracts/DidManager";
import Environment, { Network } from "models/Configuration";
import { logif } from "scripts/utils";
import VMStorage from "models/contracts/VMStorage";
import { CodeTrust, CodeTrust__factory } from "typechain-types";

//* Generic Constants
const ENABLE_LOG = true; // set to true to see logs

//* Specific Constants
const CONTRACT_NAME = "DidManager";
const DID_MANAGER_DEPLOYED_AT = undefined;

//* General Variables
let provider: Provider;
let network: Network;
let accounts: CustomWallet[] = [];
let lastBlock: Block | null;
//* Specific Variables
// Wallets | Accounts
let deployer: CustomWallet;
let deployer1: CustomWallet;
let defaultUser: CustomWallet;
// Contracts
let codeTrust: CodeTrust;
let vmStorage: VMStorage;
let didManager: DidManager;
describe("DidManager", () => {
  before("Generate test Accounts", async () => {
    ({ provider: provider, network: network } = new Environment(hre));
    lastBlock = await provider.getBlock("latest");
    if (!lastBlock || lastBlock.number < 0) {
      throw new Error(
        `❌  🛜  Cannot connect with Provider. No block number could be retreived`,
      );
    }
    console.log(
      `✅  🛜  Connected to network: ${network.name} (latest block: ${lastBlock.number})`,
    );
    // Generate TEST.accountNumber wallets
    const baseWallet = CustomWallet.fromPhrase(
      undefined,
      provider,
      KEYSTORE.default.mnemonic.basePath,
    );
    for (let index = 0; index < TEST.accountNumber; index++) {
      accounts.push(
        new CustomWallet(baseWallet.deriveChild(index).privateKey, provider),
      );
    }
    // set specific roles
    [deployer, deployer1, defaultUser] = accounts;
  });

  describe("Deployment and Initialization", () => {
    if (DID_MANAGER_DEPLOYED_AT) {
      step("Should create contract instance", async () => {
        didManager = new DidManager(DID_MANAGER_DEPLOYED_AT, deployer);
        expect(isAddress(didManager.address)).to.be.true;
        expect(didManager.address).to.equal(DID_MANAGER_DEPLOYED_AT);
        logif(
          ENABLE_LOG,
          `${CONTRACT_NAME} contract recovered at: ${didManager.address}`,
        );
      });
    } else {
      step("Should deploy CodeTrust contract", async () => {
        codeTrust = await new CodeTrust__factory(deployer).deploy();
        expect(isAddress(await codeTrust.getAddress())).to.be.true;
        expect(await codeTrust.getAddress()).not.to.equal(ZeroAddress);
        logif(
          ENABLE_LOG,
          `NEW CodeTrust contract deployed at: ${await codeTrust.getAddress()}`,
        );
      });
      step("Should deploy VMStorage contract", async () => {
        const deployResult = await VMStorage.deployVMStorage(deployer);
        vmStorage = deployResult.contract;
        expect(isAddress(vmStorage.address)).to.be.true;
        expect(vmStorage.address).not.to.equal(ZeroAddress);
        logif(
          ENABLE_LOG,
          `NEW VMStorage contract deployed at: ${vmStorage.address}`,
        );
      });
      // TODO: ServiceStorage
      step("Should deploy contract", async () => {
        const deployResult = await DidManager.deployDidManager(
          deployer,
          vmStorage.address,
          ZeroAddress,
        );
        didManager = deployResult.contract;
        expect(isAddress(didManager.address)).to.be.true;
        expect(didManager.address).not.to.equal(ZeroAddress);
        logif(
          ENABLE_LOG,
          `NEW ${CONTRACT_NAME} contract deployed at: ${didManager.address}`,
        );
      });
      step("Should initialize VMStorage contract", async () => {
        await vmStorage.initialize(
          await codeTrust.getAddress(),
          didManager.address,
        );
        expect(await vmStorage.isInitialized()).to.be.true;
        expect(
          await codeTrust.isTrustedCode(
            didManager.address,
            vmStorage.address,
            0,
          ),
        ).to.be.true;
      });
    }
  });

  describe("Main", () => {
    // before("Set the correct signer", async () => {
    //   didManager = didManager.connect(defaultUser);
    // });
    step("Should create new default DID", async () => {
      // check initial state
      // const previous = await didManager.retrieve();
      // expect(previous).equal(INIT_VALUE);
      // Create DID
      const createResult = await didManager.createDid();
      expect(createResult).not.to.be.undefined;
      expect(createResult.receipt).not.to.be.undefined;
      expect(createResult.receipt.status).to.equal(1);
      expect(createResult.event).not.to.be.undefined;
      // check final state
      // const final = await didManager.retrieve();
      // expect(final).to.equal(newValue);
    });

    step("Should create new DID", async () => {
      // check initial state
      // const previous = await didManager.retrieve();
      // expect(previous).equal(INIT_VALUE);
      // Create DID
      const createResult = await didManager.createDid(
        "MyMethod",
        "randomStringldkfa;sdlgkafgiengdlkvnporingkldgnsd;glkn",
        "verifMethod_01",
      );
      expect(createResult).not.to.be.undefined;
      expect(createResult.receipt).not.to.be.undefined;
      expect(createResult.receipt.status).to.equal(1);
      expect(createResult.event).not.to.be.undefined;
      // check final state
      // const final = await didManager.retrieve();
      // expect(final).to.equal(newValue);
    });
  });
});
