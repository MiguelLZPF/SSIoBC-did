import {
  Provider,
  Signer,
  ContractRunner,
  BigNumberish,
  Overrides,
  BytesLike,
} from "ethers";
import { Create2 as Create2Base, Create2__factory } from "typechain-types";
import CustomContract, { CCDeployResult } from "models/CustomContract";
import { GAS_OPT } from "configuration";

const GAS = {
  undefined: GAS_OPT,
  default: GAS_OPT,
  deploy: {
    ...GAS_OPT,
    gasLimit: 700000,
  },
  store: {
    ...GAS_OPT,
    gasLimit: 30000,
  },
  payMe: {
    ...GAS_OPT,
    gasLimit: 50000,
  },
  grantRole: {
    ...GAS_OPT,
    gasLimit: 110000,
  },
  revokeRole: {
    ...GAS_OPT,
    gasLimit: 50000,
  },
  transferOwnership: {
    ...GAS_OPT,
    gasLimit: 110000 + 50000,
  },
};

export default class Create2 extends CustomContract<Create2Base> {
  gas = GAS;

  constructor(address: string, signer: Signer);
  constructor(address: string, provider: Provider);
  constructor(address: string, runner: ContractRunner);
  constructor(address: string, runner: ContractRunner) {
    super(address, Create2__factory.abi, runner);
  }

  static async deployStorage(
    signer: Signer,
    initialValue?: number,
    overrides: Overrides = GAS.deploy,
  ): Promise<StorageDeployResult> {
    const deployResult = await super.deploy<Storage__factory, StorageType>(
      new Storage__factory(signer),
      undefined,
      initialValue ? [initialValue] : undefined,
      overrides,
    );
    return {
      contract: new Storage(deployResult.contract.address, signer),
      receipt: deployResult.receipt,
    };
  }

  //* Custom contract functions
  // Access Control
  async grantRole(
    role: BytesLike,
    account: string,
    overrides: Overrides = GAS_OPT.max,
  ) {
    // Check if valid address
    this._checkAddress(account);
    // Check if valid signer
    this._checkSigner();
    // Actual transaction
    const receipt = await (
      await this.contract.grantRole(role, account, { ...overrides })
    ).wait();
    if (!receipt) {
      throw new Error(
        `❌  ⛓️  Cannot grant role "${role}" to ${account}. Receipt is undefined`,
      );
    }
    // Search for events to secure execution
    let events = await this.contract.queryFilter(
      this.contract.filters.RoleGranted(
        role,
        account,
        await this.signer.getAddress(),
      ),
      receipt.blockNumber,
      receipt.blockNumber,
    );
    if ((await this._checkExecutionEvent(events)) !== true) {
      throw new Error(
        `❌  ⛓️  Cannot grant role "${role}" to ${account}. Execution event not found`,
      );
    }
    // All OK Transacction executed
    return {
      receipt: receipt,
      event: events[0],
    };
  }

  async revokeRole(
    role: BytesLike,
    account: string,
    overrides: Overrides = GAS_OPT.max,
  ) {
    // Check if valid address
    this._checkAddress(account);
    // Check if valid signer
    this._checkSigner();
    // Actual transaction
    const receipt = await (
      await this.contract.revokeRole(role, account, { ...overrides })
    ).wait();
    if (!receipt) {
      throw new Error(
        `❌  ⛓️  Cannot revoke role "${role}" to ${account}. Receipt is undefined`,
      );
    }
    // Search for events to secure execution
    let events = await this.contract.queryFilter(
      this.contract.filters.RoleRevoked(
        role,
        account,
        await this.signer.getAddress(),
      ),
      receipt.blockNumber,
      receipt.blockNumber,
    );
    if ((await this._checkExecutionEvent(events)) !== true) {
      throw new Error(
        `❌  ⛓️  Cannot revoke role "${role}" to ${account}. Execution event not found`,
      );
    }
    // All OK Transacction executed
    return {
      receipt: receipt,
      event: events[0],
    };
  }

  async hasRole(role: BytesLike, account: string) {
    return this.contract.hasRole(role, account);
  }

  // Ownable as AccessControl
  async transferOwnership(newOwner: string, overrides?: Overrides) {
    const oldOwner = this.owner();
    const grantResult = await this.grantRole(
      await this.defaultAdminRole,
      newOwner,
      overrides,
    );
    const revokeResult = await this.revokeRole(
      await this.defaultAdminRole,
      await oldOwner,
      overrides,
    );
    return {
      oldOwner: await oldOwner,
      newOwner: await this.owner(),
      receipt: { grant: grantResult.receipt, revoke: revokeResult.receipt },
      event: { granted: grantResult.event, revoked: revokeResult.event },
    };
  }

  async isSignerOwner() {
    return (await this.owner()) === (await this.signer.getAddress());
  }

  async owner() {
    const owner = await this.contract.getRoleMember(
      await this.defaultAdminRole,
      0,
    );
    this._checkAddress(owner);
    return owner;
  }

  get defaultAdminRole() {
    return this.DEFAULT_ADMIN_ROLE || this.contract.DEFAULT_ADMIN_ROLE();
  }

  // Storage
  async store(num: BigNumberish, overrides: Overrides = GAS_OPT.max) {
    // Check if valid signer
    this._checkSigner();
    // Actual transaction
    const receipt = await (
      await this.contract.store(num, { ...overrides })
    ).wait();
    if (!receipt) {
      throw new Error(
        `❌  ⛓️  Cannot store ${num} in ${this.address}. Receipt is undefined`,
      );
    }
    // Search for events to secure execution
    let events = await this.contract.queryFilter(
      this.contract.filters.Stored(num),
      receipt?.blockNumber,
      receipt?.blockNumber,
    );
    if ((await this._checkExecutionEvent(events)) !== true) {
      throw new Error(
        `❌  ⛓️  Cannot store ${num} in ${this.address}. Execution event not found`,
      );
    }
    // All OK Transacction executed
    return { num: num, receipt: receipt, event: events[0] };
  }

  async payMe(overrides: Overrides = GAS_OPT.max) {
    // Check if valid signer
    this._checkSigner();
    // Actual transaction
    const receipt = await (await this.contract.payMe({ ...overrides })).wait();
    if (!receipt) {
      throw new Error(
        `❌  ⛓️  Cannot pay in ${this.address}. Receipt is undefined`,
      );
    }
    // Search for events to secure execution
    let events = await this.contract.queryFilter(
      this.contract.filters.ThankYou(
        await this.owner(),
        await this.signer.getAddress(),
        undefined,
      ),
      receipt?.blockNumber,
      receipt?.blockNumber,
    );
    if ((await this._checkExecutionEvent(events)) !== true) {
      throw new Error(
        `❌  ⛓️  Cannot pay in ${this.address}. Execution event not found`,
      );
    }
    // All OK Transacction executed
    return { receipt: receipt, event: events[0] };
  }

  async retrieve(): Promise<BigInt | number> {
    let result: BigInt | number = await this.contract.retrieve();
    try {
      result = Number(result);
    } catch (error) {
      console.warn(`🟠  Cannot convert to number: ${error}`);
    }
    this.number = result;
    return result;
  }
}

export interface StorageDeployResult
  extends Omit<CCDeployResult<StorageType>, "contract"> {
  contract: Storage;
}
