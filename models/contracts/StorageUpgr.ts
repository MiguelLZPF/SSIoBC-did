import {
  Signer,
  ContractFactory,
  ContractRunner,
  BigNumberish,
  BytesLike,
  Overrides,
} from "ethers";
import {
  AccessControlEnumerable,
  ERC1967Proxy,
  StorageUpgr as StorageBase,
  StorageUpgr__factory,
} from "typechain-types";
import CustomUpgrContract, {
  ICCUpgrDeployResult as CCUpgrDeployResult,
} from "models/CustomUpgrContract";
import { GAS_OPT } from "configuration";

const GAS = {
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

type StorageType = StorageBase & AccessControlEnumerable;

export default class StorageUpgr extends CustomUpgrContract<StorageType> {
  private DEFAULT_ADMIN_ROLE: string | undefined;
  gas = GAS;
  number?: number | BigInt;

  constructor(proxy: ERC1967Proxy, logic: StorageType, runner: ContractRunner);
  constructor(proxy: string, logic: string, runner: ContractRunner);
  constructor(
    proxy: ERC1967Proxy | string,
    logic: StorageType | string,
    runner: ContractRunner,
  ) {
    super(
      (proxy as string) || ((proxy as ERC1967Proxy).target as string),
      (logic as string) || ((logic as StorageType).target as string),
      StorageUpgr__factory.abi,
      runner,
    );
    this.number = undefined;
  }

  static async deployStorage(
    signer: Signer,
    initialValue?: number,
    overrides: Overrides = GAS_OPT.max,
  ): Promise<StorageUpgrDeployResult> {
    const deployResult = await super.deployUpgradeable<
      StorageUpgr__factory,
      StorageType
    >(
      new StorageUpgr__factory(signer),
      signer,
      initialValue ? [initialValue] : undefined,
      overrides,
    );
    return {
      contract: new StorageUpgr(
        deployResult.contract.proxyAddress,
        deployResult.contract.logicAddress,
        signer,
      ),
      receipt: deployResult.receipt,
    };
  }

  async upgradeStorage<F extends ContractFactory>(
    factory?: F,
    // initialValue?: number,
    overrides?: Overrides,
  ): Promise<StorageUpgrDeployResult> {
    const upgradeResult = await super.upgrade(
      factory || new StorageUpgr__factory(this.signer),
      // initialValue ? [initialValue] : undefined,
      overrides,
    );
    return {
      contract: new StorageUpgr(
        upgradeResult.contract.proxyAddress,
        upgradeResult.contract.logicAddress,
        this.signer,
      ),
      receipt: upgradeResult.receipt,
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

export interface StorageUpgrDeployResult
  extends Omit<CCUpgrDeployResult<StorageType>, "contract"> {
  contract: StorageUpgr;
}
