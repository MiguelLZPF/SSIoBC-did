import {
  Provider,
  Signer,
  ContractRunner,
  BigNumberish,
  Overrides,
  BytesLike,
  ZeroAddress,
} from "ethers";

import CustomContract, { CCDeployResult } from "models/CustomContract";
import { GAS_OPT } from "configuration";
import { Create2Deployable, Create2Deployable__factory } from "typechain-types";

const GAS = {
  undefined: GAS_OPT.max,
  default: GAS_OPT.max,
  deploy: {
    ...GAS_OPT.max,
    gasLimit: 700000,
  },
  store: {
    ...GAS_OPT.max,
    gasLimit: 30000,
  },
  payMe: {
    ...GAS_OPT.max,
    gasLimit: 50000,
  },
  grantRole: {
    ...GAS_OPT.max,
    gasLimit: 110000,
  },
  revokeRole: {
    ...GAS_OPT.max,
    gasLimit: 50000,
  },
  transferOwnership: {
    ...GAS_OPT.max,
    gasLimit: 110000 + 50000,
  },
};

export default class Create2 extends CustomContract<Create2Deployable> {
  gas = GAS;

  constructor(address: string, signer: Signer);
  constructor(address: string, provider: Provider);
  constructor(address: string, runner: ContractRunner);
  constructor(address: string, runner: ContractRunner) {
    super(address, Create2Deployable__factory.abi, runner);
  }

  static async deployCreate2(
    signer: Signer,
    overrides: Overrides = GAS.deploy,
  ): Promise<Create2DeployResult> {
    const deployResult = await super.deploy<
      Create2Deployable__factory,
      Create2Deployable
    >(new Create2Deployable__factory(signer), signer, undefined, overrides);
    return {
      contract: new Create2(deployResult.contract.address, signer),
      receipt: deployResult.receipt,
    };
  }

  //* Custom contract functions
  async deploy(
    amount: BigNumberish = 0,
    salt: BytesLike,
    bytecode: BytesLike,
    overrides: Overrides = GAS_OPT.max,
  ) {
    // Check if valid signer
    this._checkSigner();
    // Actual transaction
    const receipt = await (
      await this.contract.deploy(amount, salt, bytecode, { ...overrides })
    ).wait();
    if (!receipt) {
      throw new Error(`❌  ⛓️  Cannot deploy contract. Receipt is undefined`);
    }
    // Search for events to secure execution
    let events = await this.contract.queryFilter(
      this.contract.filters.Deployed(undefined, await this.signer.getAddress()),
      receipt.blockNumber,
      receipt.blockNumber,
    );
    if ((await this._checkExecutionEvent(events)) !== true) {
      throw new Error(
        `❌  ⛓️  Cannot deploy contract. Execution event not found`,
      );
    }
    // All OK Transacction executed
    return {
      receipt: receipt,
      event: events[0],
    };
  }

  async computeAddress(
    salt: BytesLike,
    bytecodeHash: BytesLike,
    deployer: string = ZeroAddress,
    overrides: Overrides = GAS_OPT.max,
  ) {
    this._checkAddress(deployer);
    return this.contract.computeAddress(salt, bytecodeHash, deployer);
  }
}

export interface Create2DeployResult
  extends Omit<CCDeployResult<Create2Deployable>, "contract"> {
  contract: Create2;
}
