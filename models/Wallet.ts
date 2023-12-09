import { KEYSTORE } from "configuration";
import {
  Wallet,
  Provider,
  HDNodeWallet,
  ProgressCallback,
  SigningKey,
} from "ethers";
import { writeFileSync } from "fs";
import { checkDirectoriesInPath } from "scripts/utils";
import { ENV } from "./Configuration";

export default class CustomWallet extends Wallet {
  constructor(
    key: string | SigningKey = KEYSTORE.default.privateKey,
    provider: Provider = ENV.provider,
  ) {
    super(key, provider);
  }

  static override createRandom(
    provider: Provider = ENV.provider,
  ): HDNodeWallet {
    return super.createRandom(provider);
  }

  static override fromPhrase(
    phrase: string = KEYSTORE.default.mnemonic.phrase,
    provider: Provider = ENV.provider,
    path: string = KEYSTORE.default.mnemonic.path,
  ): HDNodeWallet {
    return HDNodeWallet.fromPhrase(
      phrase.toLowerCase() === "default"
        ? KEYSTORE.default.mnemonic.phrase
        : phrase,
      undefined,
      path,
    ).connect(provider);
  }

  static override async fromEncryptedJson(
    json: string,
    password: string | Uint8Array = KEYSTORE.default.password,
    progress?: ProgressCallback,
    isAbsolutePath = false,
    provider = ENV.provider,
  ): Promise<CustomWallet | HDNodeWallet> {
    if (!isAbsolutePath) {
      // remove "/"
      json = json[0] == "/" ? json.substring(1) : json;
      // add .json extension
      json = json.endsWith(".json") ? json : `${json}.json`;
      // full path relative to project root. example: keystore/relativePath"
      json = `${KEYSTORE.root}/${json}`;
    }
    checkDirectoriesInPath(json);
    return (await super.fromEncryptedJson(json, password, progress)).connect(
      provider,
    ) as CustomWallet | HDNodeWallet;
  }
  static override fromEncryptedJsonSync(
    json: string,
    password: string | Uint8Array = KEYSTORE.default.password,
    isAbsolutePath = false,
    provider: Provider = ENV.provider,
  ): CustomWallet | HDNodeWallet {
    if (!isAbsolutePath) {
      // remove "/"
      json = json[0] == "/" ? json.substring(1) : json;
      // add .json extension
      json = json.endsWith(".json") ? json : `${json}.json`;
      // full path relative to project root. example: keystore/relativePath"
      json = `${KEYSTORE.root}/${json}`;
    }
    checkDirectoriesInPath(json);
    return super.fromEncryptedJsonSync(json, password).connect(provider) as
      | CustomWallet
      | HDNodeWallet;
  }

  override async encrypt(
    password: string | Uint8Array = KEYSTORE.default.password,
    progressCallback?: ProgressCallback | undefined,
  ): Promise<string> {
    return super.encrypt(password, progressCallback);
  }
  override encryptSync(
    password: string | Uint8Array = KEYSTORE.default.password,
  ): string {
    return super.encryptSync(password);
  }

  storeEncrypted(
    path: string,
    password: string | Uint8Array = KEYSTORE.default.password,
    isAbsolutePath = false,
  ) {
    if (!isAbsolutePath) {
      // remove "/"
      path = path[0] == "/" ? path.substring(1) : path;
      // add .json extension
      path = path.endsWith(".json") ? path : `${path}.json`;
      // full path relative to project root. example: keystore/relativePath"
      path = `${KEYSTORE.root}/${path}`;
    }
    writeFileSync(path, this.encryptSync(password));
    return path;
  }
}
