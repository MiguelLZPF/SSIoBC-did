import { GAS_OPT, TEST } from "configuration";
import hre from "hardhat";
import {
  Signer,
  Provider,
  Block,
  ZeroAddress,
  Interface,
  BaseContract,
} from "ethers";
import { setGlobalHRE } from "scripts/utils";
import { INetwork } from "models/Configuration";
import { Storage, Storage__factory } from "typechain-types";
import CustomContract from "models/CustomContract";
import { expect } from "chai";
import CustomWallet from "models/Wallet";

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
let contract: CustomContract<Storage>;
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
      const deployResult = await CustomContract.deploy<
        Storage__factory,
        Storage
      >(
        Storage__factory.abi,
        Storage__factory.bytecode,
        admin,
        [12],
        GAS_OPT.max,
      );
      expect(deployResult).not.to.be.undefined;
      contract = deployResult.contract;
      expect(contract).not.to.be.undefined;
      expect(deployResult.receipt).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
    it("Should deploy a new custom contract using Factory", async () => {
      const deployResult = await CustomContract.deploy<
        Storage__factory,
        Storage
      >(new Storage__factory(admin), admin, [12], GAS_OPT.max);
      expect(deployResult).not.to.be.undefined;
      contract = deployResult.contract;
      expect(contract).not.to.be.undefined;
      expect(deployResult.receipt).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
    it("Should deploy a new custom contract using Factory and no signer", async () => {
      const deployResult = await CustomContract.deploy<
        Storage__factory,
        Storage
      >(new Storage__factory(admin), undefined, [12], GAS_OPT.max);
      expect(deployResult).not.to.be.undefined;
      contract = deployResult.contract;
      expect(contract).not.to.be.undefined;
      expect(deployResult.receipt).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
  });
  describe("Create new Instance", () => {
    it("Should not create a new CC instance with an invalid address", async () => {
      expect(() => {
        new CustomContract<Storage>(
          "0xAABBCC00112233",
          contract.interface,
          admin,
        );
      }).to.throw(
        `❌  ⬇️  Bad input address is not a valid address: ${"0xAABBCC00112233"}`,
      );
    });
    it("Should create a new custom contract instance using address, ABI and signer", async () => {
      contract = new CustomContract(
        contract.address,
        contract.interface,
        admin,
      );
      expect(contract).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
    it("Should create a new custom contract instance using address, ABI and provider", async () => {
      contract = new CustomContract(
        contract.address,
        contract.interface,
        provider,
      );
      expect(contract).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
    it("Should not create a new CC instance without a runner", async () => {
      expect(() => {
        new CustomContract<Storage>(
          new BaseContract(contract.address, contract.interface) as Storage,
        );
      }).to.throw(`❌  🛜  No provider detected. Instance not connected`);
    });
    it("Should create a new custom contract instance from previous instance with signer", async () => {
      const normalContract = contract.contract;
      contract = new CustomContract(normalContract);
      expect(contract).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
    it("Should create a new custom contract instance from previous instance with provider", async () => {
      const normalContract = contract.contract;
      contract = new CustomContract(normalContract.connect(provider));
      expect(contract).not.to.be.undefined;
      expect(contract.target).to.equal(contract.address);
      expect(contract.target).to.equal(await contract.getAddress());
      expect(contract.address).to.equal(await contract.getAddress());
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.to.be.null;
      expect(deployedCode).to.equal(await provider.getCode(contract.address));
    });
  });
  describe("Other functionality", () => {
    it("Should connect to another signer and provider", async () => {
      // Normal
      contract.connect(admin);
      expect(contract.runner).not.undefined.and.not.null;
      expect(await (contract.runner! as Signer).getAddress()).not.eq(
        ZeroAddress,
      );
      expect(await contract.signer.getAddress()).not.eq(ZeroAddress);
      // Other
      const previousRunner = contract.runner;
      contract.connect(defaultUser);
      expect(contract.runner).eq(defaultUser).and.not.eq(previousRunner);
      // Provider
      contract.connect(provider);
      expect(contract.runner).eq(provider);
      expect(contract.provider).eq(provider);
      // Leave it with default admin
      contract.connect(admin);
    });
    it("Should check interface", async () => {
      expect(contract.interface.fragments[0].inputs[0].name).to.eq(
        new Interface(Storage__factory.abi).fragments[0].inputs[0].name,
      );
    });
    it("Should get deployed bytecode", async () => {
      const deployedCode = await contract.getDeployedCode();
      expect(deployedCode).not.undefined.and.not.null.and.not.eq("0x00");
    });
    it("Should attach to another address", async () => {
      expect(contract.address).not.undefined.and.not.eq(ZeroAddress);
      const previousAddress = contract.address;
      const randomAddress = CustomWallet.createRandom(provider).address;
      contract.attach(randomAddress);
      expect(contract.address).eq(randomAddress).and.not.eq(previousAddress);
    });
  });
});
