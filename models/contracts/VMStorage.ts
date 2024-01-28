import {
  Provider,
  Signer,
  ContractRunner,
  Overrides,
  BytesLike,
  encodeBytes32String,
  keccak256,
  AbiCoder,
} from "ethers";
import {
  VMStorage as VMStorageType,
  VMStorage__factory,
} from "typechain-types";
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

/**
 * Represents a VMStorage contract.
 */
export default class VMStorage extends CustomContract<VMStorageType> {
  gas = GAS;

  constructor(address: string, signer: Signer);
  constructor(address: string, provider: Provider);
  constructor(address: string, runner: ContractRunner);
  constructor(address: string, runner: ContractRunner) {
    super(address, VMStorage__factory.abi, runner);
  }

  static async deployVMStorage(
    signer: Signer,
    overrides: Overrides = GAS.deploy,
  ): Promise<VMStorageDeployResult> {
    const deployResult = await super.deploy<VMStorage__factory, VMStorageType>(
      new VMStorage__factory(signer),
      undefined,
      undefined,
      overrides,
    );
    return {
      contract: new VMStorage(deployResult.contract.address, signer),
      receipt: deployResult.receipt,
    };
  }

  //* Custom contract functions
  // SimpleInitializable
  async initialize(
    codeTrust: string,
    didManager: string,
    overrides: Overrides = GAS_OPT.max,
  ) {
    this._checkAddress(codeTrust, didManager);
    //* Actual transaction
    const receipt = await (
      await this.contract.initialize(codeTrust, didManager, { ...overrides })
    ).wait();
    if (!receipt) {
      throw new Error(`❌  ⛓️  Cannot validate VM. Receipt is undefined`);
    }
  }
  async isInitialized() {
    return await this.contract.isInitialized();
  }
  // VMStorage
  async createVM(
    did: string,
    verificationMethodId: string = "vm-0",
    type?: string, // EcdsaSecp256k1VerificationKey2019
    publicKeyHex?: string,
    blockchainAccountId?: string,
    thisBlockchainAccountAddress?: string,
    expiration?: Date,
    overrides: Overrides = GAS_OPT.max,
  ) {
    // Check if valid signer
    this._checkSigner();
    //* Extract DID id and methods
    const splitDid = did.split(":");
    const length = splitDid.length;
    if (length < 3) {
      throw new Error(
        `❌  ⛓️  Cannot create VM. Invalid DID format: ${did}. Expected: did:method0:method1:method2:id`,
      );
    }
    // Extract the first and last elements
    const preamble = splitDid[0];
    if (preamble !== "did") {
      throw new Error(
        `❌  ⛓️  Cannot create VM. Invalid DID format: ${did}. DID string must start with 'did'`,
      );
    }
    const id = splitDid[length - 1];
    // Extract the elements in between
    const [method0, method1, method2] = splitDid.slice(1, length - 1);
    //* Parameters validation
    if (!method0) {
      throw new Error(
        `❌  ⛓️  Cannot create VM. Invalid DID format: ${did}. Method 0 cannot be undefined`,
      );
    }
    if (
      !publicKeyHex &&
      !blockchainAccountId &&
      !thisBlockchainAccountAddress
    ) {
      throw new Error(
        `❌  ⛓️  Cannot create VM. Invalid VM format: ${did}. publicKeyHex, blockchainAccountId and thisBlockchainAccountAddress cannot be all undefined`,
      );
    }
    const method0Encoded = encodeBytes32String(method0);
    const method1Encoded = method1
      ? encodeBytes32String(method1)
      : new Uint8Array(32);
    const method2Encoded = method2
      ? encodeBytes32String(method2)
      : new Uint8Array(32);
    const idEncoded = encodeBytes32String(id);
    const didHash = keccak256(
      new AbiCoder().encode(
        ["bytes32", "bytes32", "bytes32", "bytes32"],
        [method0Encoded, method1Encoded, method2Encoded, idEncoded],
      ),
    );
    const typeEncoded = type
      ? this._encodeBytes32String(type, 2)
      : this._encodeBytes32String("", 2);
    const publicKeyHexEncoded = publicKeyHex
      ? this._encodeBytes32String(publicKeyHex, 16)
      : this._encodeBytes32String("", 16);
    const blockchainAccountIdEncoded = blockchainAccountId
      ? this._encodeBytes32String(blockchainAccountId, 5)
      : this._encodeBytes32String("", 5);
    //* Actual transaction
    const receipt = await (
      await this.contract.createVM(
        didHash,
        encodeBytes32String(verificationMethodId),
        [typeEncoded[0], typeEncoded[1]],
        [
          publicKeyHexEncoded[0],
          publicKeyHexEncoded[1],
          publicKeyHexEncoded[2],
          publicKeyHexEncoded[3],
          publicKeyHexEncoded[4],
          publicKeyHexEncoded[5],
          publicKeyHexEncoded[6],
          publicKeyHexEncoded[7],
          publicKeyHexEncoded[8],
          publicKeyHexEncoded[9],
          publicKeyHexEncoded[10],
          publicKeyHexEncoded[11],
          publicKeyHexEncoded[12],
          publicKeyHexEncoded[13],
          publicKeyHexEncoded[14],
          publicKeyHexEncoded[15],
        ],
        [
          blockchainAccountIdEncoded[0],
          blockchainAccountIdEncoded[1],
          blockchainAccountIdEncoded[2],
          blockchainAccountIdEncoded[3],
          blockchainAccountIdEncoded[4],
        ],
        thisBlockchainAccountAddress!,
        expiration ? Math.floor(expiration.getTime() / 1000) : 0,
        { ...overrides },
      )
    ).wait();
    if (!receipt) {
      throw new Error(`❌  ⛓️  Cannot create VM. Receipt is undefined`);
    }
    // All OK Transacction executed
    return {
      receipt: receipt,
    };
  }

  /**
   * Validates a VM with the given parameters.
   * @param positionHash - The position hash of the VM.
   * @param expiration - The expiration date of the VM. Optional.
   * @returns An object containing the receipt of the transaction.
   * @throws An error if the receipt is undefined.
   */
  async validateVM(
    positionHash: BytesLike,
    expiration?: Date,
    sender?: string,
    overrides?: Overrides,
  ) {
    // Check if valid signer
    this._checkSigner();
    //* Actual transaction
    const receipt = await (
      await this.contract.validateVM(
        positionHash,
        expiration ? Math.floor(expiration.getTime() / 1000) : 0,
        sender ?? (await this.signer.getAddress()),
        { ...overrides },
      )
    ).wait();
    if (!receipt) {
      throw new Error(`❌  ⛓️  Cannot validate VM. Receipt is undefined`);
    }
    // All OK Transacction executed
    return {
      receipt: receipt,
    };
  }

  //* Private | Internal
  /**
   * Encodes a string into an array of bytes32 strings.
   * @param inputString The string to be encoded.
   * @param finalLength The final length of the resulting array. If not provided, the array will have the same length as the input string.
   * @returns An array of bytes32 strings.
   */
  private _encodeBytes32String(inputString: string, finalLength?: number) {
    const stringArray = this._splitString(inputString, 31);
    if (finalLength && stringArray.length > finalLength) {
      throw new Error(
        `The final length provided is smaller than the number of chunks in the string. Final length: ${finalLength}, String chunks: ${stringArray.length}`,
      );
    }
    for (
      let i = stringArray.length;
      i < (finalLength || stringArray.length);
      i++
    ) {
      stringArray.push("");
    }
    const encoded = stringArray.map((s) => encodeBytes32String(s));
    return encoded;
  }

  /**
   * Splits a string into chunks of a specified size.
   *
   * @param inputString - The string to be split.
   * @param chunkSize - The size of each chunk. Default value is 31.
   * @returns An array of strings representing the chunks.
   */
  private _splitString(inputString: string, chunkSize: number = 31): string[] {
    const result: string[] = [];
    for (let i = 0; i < inputString.length; i += chunkSize) {
      const chunk = inputString.substring(i, i + chunkSize);
      result.push(chunk);
    }
    return result;
  }
}

export interface VMStorageDeployResult
  extends Omit<CCDeployResult<VMStorageType>, "contract"> {
  contract: VMStorage;
}
