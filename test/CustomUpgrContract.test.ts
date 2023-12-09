import { GAS_OPT, TEST } from "configuration";
import hre from "hardhat";
import {
  Signer,
  Provider,
  Block,
  ZeroAddress,
  Interface,
  keccak256,
} from "ethers";
import { setGlobalHRE } from "scripts/utils";
import { INetwork } from "models/Configuration";
import {
  StorageUpgr,
  StorageUpgrV1__factory,
  StorageUpgr__factory,
} from "typechain-types";
import CustomContract from "models/CustomContract";
import { expect } from "chai";
import CustomWallet from "models/Wallet";
import CustomUpgrContract from "models/CustomUpgrContract";

//* Specific Constants

//* General Variables
let provider: Provider;
let network: INetwork;
let accounts: CustomWallet[] = [];
let lastBlock: Block | null;
//* Specific Variables
// Wallets | Accounts
let admin: CustomWallet;
let defaultUser: CustomWallet;
// Contracts
let contract: CustomUpgrContract<StorageUpgr>;
describe("CustomContract", () => {
  before("Generate test Accounts", async () => {
    ({ gProvider: provider, gNetwork: network } = await setGlobalHRE(hre));
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
    const baseWallet = CustomWallet.fromPhrase();
    for (let index = 0; index < TEST.accountNumber; index++) {
      accounts.push(
        new CustomWallet(baseWallet.deriveChild(index).privateKey, provider),
      );
    }
    // set specific roles
    admin = accounts[0];
    defaultUser = accounts[1];
  });

  describe("Deployment", () => {
    it("Should deploy a new custom contract using ABI and Bytecode", async () => {
      const deployResult = await CustomUpgrContract.deployUpgradeable<
        StorageUpgr__factory,
        StorageUpgr
      >(
        StorageUpgr__factory.abi,
        StorageUpgr__factory.bytecode,
        admin,
        [12],
        GAS_OPT.max,
      );
      expect(deployResult).not.undefined;
      contract = deployResult.contract;
      expect(contract).not.undefined;
      expect(deployResult.receipt).not.undefined;
      expect(contract.target)
        .to.eq(contract.address)
        .to.eq(contract.proxyAddress)
        .to.eq(contract.storageAddress)
        .to.eq(await contract.getAddress());
      expect(contract.logicAddress)
        .to.eq(contract.implementationAddress)
        .to.not.eq(contract.proxyAddress);
      const deployedCodeHash = keccak256((await contract.getDeployedCode())!);
      expect(deployedCodeHash).not.undefined.null;
      expect(deployedCodeHash).to.eq(
        keccak256(await provider.getCode(contract.logicAddress)),
      );
    });
    it("Should deploy a new custom contract using Factory", async () => {
      const deployResult = await CustomUpgrContract.deployUpgradeable<
        StorageUpgr__factory,
        StorageUpgr
      >(new StorageUpgr__factory(admin), admin, [12], GAS_OPT.max);
      expect(deployResult).not.undefined;
      contract = deployResult.contract;
      expect(contract).not.undefined;
      expect(deployResult.receipt).not.undefined;
      expect(contract.target)
        .to.eq(contract.address)
        .to.eq(contract.proxyAddress)
        .to.eq(contract.storageAddress)
        .to.eq(await contract.getAddress());
      expect(contract.logicAddress)
        .to.eq(contract.implementationAddress)
        .to.not.eq(contract.proxyAddress);
      const deployedCodeHash = keccak256((await contract.getDeployedCode())!);
      expect(deployedCodeHash).not.undefined.null;
      expect(deployedCodeHash).to.eq(
        keccak256(await provider.getCode(contract.logicAddress)),
      );
    });
    it("Should Upgrade to a new logic", async () => {
      // Check implementation chage
      const NUM = 8;
      await contract.contract.store(NUM);
      const resultV0 = await contract.contract.retrieve();
      expect(Number(resultV0)).to.eq(NUM);
      const deployResult = await contract.upgrade(
        new StorageUpgrV1__factory(),
        GAS_OPT.max,
      );
      expect(deployResult).not.undefined;
      contract = deployResult.contract;
      expect(contract).not.undefined;
      expect(deployResult.receipt).not.undefined;
      expect(contract.target)
        .to.eq(contract.address)
        .to.eq(contract.proxyAddress)
        .to.eq(contract.storageAddress)
        .to.eq(await contract.getAddress());
      expect(contract.logicAddress)
        .to.eq(contract.implementationAddress)
        .to.not.eq(contract.proxyAddress);
      const deployedCodeHash = keccak256((await contract.getDeployedCode())!);
      expect(deployedCodeHash).not.undefined.null;
      expect(deployedCodeHash).to.eq(
        keccak256(await provider.getCode(contract.logicAddress)),
      );
      // Check implementation chage
      await contract.contract.store(NUM);
      const resultV1 = await contract.contract.retrieve();
      expect(Number(resultV1)).to.eq(NUM + 2);
      expect(Number(resultV1)).not.to.eq(Number(resultV0));
    });
  });
  describe("Create new Instance", () => {
    it("Should create a new custom contract instance using address and ABI", async () => {
      contract = new CustomUpgrContract(
        contract.address as string,
        contract.implementationAddress as string,
        contract.logic!.interface,
        admin,
      );
      expect(contract).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      expect(await contract.getDeployedCode()).not.to.be.null;
      expect(await contract.getDeployedCode()).to.equal(
        await provider.getCode(contract.implementation),
      );
    });
    it("Should create a new custom contract instance from previous instance", async () => {
      const normalContract = contract.contract;
      const normalLogic = contract.logic;
      contract = new CustomUpgrContract(normalContract, normalLogic);
      expect(contract).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      expect(await contract.getDeployedCode()).not.to.be.null;
      expect(await contract.getDeployedCode()).to.equal(
        await provider.getCode(contract.implementation),
      );
    });
  });
  describe("Other functionality", () => {
    it("Should get various information about contract", async () => {
      expect(contract.runner).to.eq(admin);
      expect(contract.interface.fragments[1].inputs[0].name).to.eq(
        new Interface(StorageUpgr__factory.abi).fragments[1].inputs[0].name,
      );
      expect(contract.target).to.eq(contract.address);
      expect(await contract.getDeployedCode()).not.to.be.undefined;
      expect(await contract.getDeployedCode()).not.to.be.null;
      expect(await contract.getDeployedCode()).not.to.eq("0x00");
    });
    it("Should attach to another address", async () => {
      expect(contract.address).not.to.be.undefined;
      expect(contract.address).not.to.equal(ZeroAddress);
      const previousAddress = contract.address;
      const randomAddress = CustomWallet.createRandom(provider).address;
      contract.attach(randomAddress);
      expect(contract.address).to.equal(randomAddress);
      expect(contract.address).not.to.equal(previousAddress);
    });
    it("Should connect to another signer", async () => {
      expect(contract.runner).not.to.be.undefined;
      expect(contract.runner).not.to.be.null;
      expect(await (contract.runner! as Signer).getAddress()).not.to.equal(
        ZeroAddress,
      );
      const previousRunner = contract.runner;
      contract.connect(defaultUser);
      expect(contract.runner).to.equal(defaultUser);
      expect(contract.runner).not.to.equal(previousRunner);
    });
  });
});
