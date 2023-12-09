# 1. Hardhat Off-Chain Deployments Base - HHoffCDB

Before running anything, make sure you run `npm install`.

This project aims to provide an easy-to-use _Hardhat base project_ that can be used to develop new smart contracts and deploy them using the _new tasks provided on top_ of a basic Hardhat project. It offers two main features: _Encrypted JSON wallet management_ and _automated off-chain deployments_ (regular and UUPS Upgradeable (EIP-1822)). This project is designed for use in private and public-permissioned networks but can also be used in public networks by adjusting a few gas options.

The project structure follows a Hardhat environment using **ethers**, **waffle**, and **chai**. It also utilizes **TypeScript** and generates smart contract types using **Typechain**. The `--network` parameter refers to the network defined in the [hardhat config file](./hardhat.config.ts).

- [1. Hardhat Off-Chain Deployments Base - HHoffCDB](#1-hardhat-off-chain-deployments-base---hhoffcdb)
  - [1.1. Custom Tasks added](#11-custom-tasks-added)
    - [AVAILABLE TASKS:](#available-tasks)
  - [1.2. Configuration file constants](#12-configuration-file-constants)
  - [1.3. Manage Encryped JSON Wallets](#13-manage-encryped-json-wallets)
    - [1.3.1. Relevant Constants](#131-relevant-constants)
    - [1.3.2. Generate one Random Wallet](#132-generate-one-random-wallet)
    - [1.3.3. Generate Batch Wallets](#133-generate-batch-wallets)
    - [1.3.4. Generate Wallet from mnemonic phrase](#134-generate-wallet-from-mnemonic-phrase)
    - [1.3.5. Get Wallet mnemonic phrase](#135-get-wallet-mnemonic-phrase)
    - [1.3.6. Get Wallet Information](#136-get-wallet-information)
  - [1.4. Deploy Smart contracts](#14-deploy-smart-contracts)
    - [1.4.1. Relevant Constants](#141-relevant-constants)
    - [1.3.2. Regular Deployment](#132-regular-deployment)
    - [1.3.3. Upgradeable deployment](#133-upgradeable-deployment)
    - [1.3.4. Upgrade deployed Smart Contract](#134-upgrade-deployed-smart-contract)
  - [1.4. Unit Test](#14-unit-test)

## 1.1. Custom Tasks added

Marked **tasks** are the ones provided by this project:

**PLEASE USE: `npx hardhat --help` and `npx hardat {{TASK_NAME}} --help`**

### AVAILABLE TASKS:
  - **call-contract**: Call a contract function (this does not change contract storage or state)
  - **change-logic**: change the actual logic|implementation smart contract of a TUP proxy
  - check                 Check whatever you need
  - clean                 Clears the cache and deletes all artifacts
  - compile               Compiles the entire project, building all artifacts
  - console               Opens a hardhat console
  - coverage              Generates a code coverage report for tests
  - **deploy**                Deploy smart contracts on '--network'
  - flatten               Flattens and prints contracts and their dependencies. If no file is passed, all the contracts in the project will be flattened.
  - gas-reporter:merge
  - **generate-wallets**      Generates Encryped JSON persistent wallets
  - **get-logic**             Check what logic|implementation smart contract address is currently using a given proxy
  - **get-mnemonic**          Recover mnemonic phrase from an encrypted wallet
  - **get-timestamp**         get the current timestamp in seconds
  - **get-wallet-info**       Recover all information from an encrypted wallet or an HD Wallet
  - help                  Prints this message
  - node                  Starts a JSON-RPC server on top of Hardhat Network
  - **quick-test**            Random quick testing function
  - run                   Runs a user-defined script after compiling the project
  - size-contracts        Output the size of compiled contracts
  - test                  Runs mocha tests
  - typechain             Generate Typechain typings for compiled contracts
  - **upgrade**               Upgrade smart contracts on '--network'
  - verify                Verifies contract on Etherscan

## 1.2. Configuration file constants

Environmental variables and constants are defined in the configuration.ts file. Simple and easy to use due to it aims to provide a development local envionment and it is not supposed to be deployed anyware.

## 1.3. Manage Encryped JSON Wallets

Automatize the management of Encryped JSON wallets using Hardhat tasks and scripts.

```text
npx hardhat generate-wallets --help
Hardhat version 2.11.0

Usage: hardhat [GLOBAL OPTIONS] generate-wallets [--batch-size <INT>] [--entropy <STRING>] [--mnemonic-path <STRING>] [--mnemonic-phrase <STRING>] [--password <STRING>] [--private-key <STRING>] --relative-path <STRING> [type]

OPTIONS:

  --batch-size          Number of user wallets to be generated in batch 
  --entropy             Wallet entropy 
  --mnemonic-path       Mnemonic path to generate wallet from 
  --mnemonic-phrase     Mnemonic phrase to generate wallet from 
  --password            Wallet password 
  --private-key         Private key to generate wallet from. Hexadecimal String format expected 
  --relative-path       Path relative to KEYSTORE.root to store the wallets 

POSITIONAL ARGUMENTS:

  type  Type of generation [single, batch] (default: "single")

generate-wallets: Generates Encryped JSON persistent wallets
```

### 1.3.1. Relevant Constants

All detailed in configuration.ts KEYSTORE constant group.

- KEYSTORE.root: defines the main keystore path to store the Encryped JSON wallets
- KEYSTORE.default.password: default password to be used to symetric encryption & decryption of the Encryped JSON wallets
- KEYSTORE.default.batchSize: default number of wallets to generate if not specified and useing the batch mode

### 1.3.2. Generate one Random Wallet

Use hardhat task to generate random Encryped JSON wallet:

```bash
npx hardhat generate-wallets single --relative-path "/new-wallet/another_path/name.json"

Generating Wallet...
WARN: No password specified, using default password
New Wallet created and stored with address: 0xf85FaB8ca3aE307980E1B1e8BF1258B1aED9EDB9 as keystore/new-wallet/another_path/name.json
```

### 1.3.3. Generate Batch Wallets

Use hardhat task to generate multiple Encryped JSON wallets at once:

```bash
npx hardhat generate-wallets batch --relative-path /new-wallets/example --password myPassword --entropy whatever --batch-size 5

Generating Wallets...
New Wallet created and stored with address: 0x620f3A7da61156B3629b3dffC59e680b1FbD55C7 as keystore/new-wallets/example00.json
New Wallet created and stored with address: 0x3F99425f19DADd37433099Fc2104dCcd59699464 as keystore/new-wallets/example01.json
New Wallet created and stored with address: 0xE5B3836211Ac74ceB63F1Dbf5FeB9bb55822e413 as keystore/new-wallets/example02.json
New Wallet created and stored with address: 0x79fe0Eb3E352E68F2CDc6D81E6109b5Fb355C24f as keystore/new-wallets/example03.json
New Wallet created and stored with address: 0x46866650c2DAFb25Aabad5c965efCD6602A89Db5 as keystore/new-wallets/example04.json
```

### 1.3.4. Generate Wallet from mnemonic phrase

Use hardhat task to generate Encryped JSON wallet from mnemonic phrase:

```bash
npx hardhat generate-wallets single --relative-path "other.json" --mnemonic "public shaft female city humor annual beauty razor club mix trip blossom"

Generating Wallet...
WARN: No password specified, using default password
New Wallet created and stored with address: 0x3e69BB8Fa07D831334E679cCEbBaB36DC42C4834 as keystore/other.json
```

### 1.3.5. Get Wallet mnemonic phrase

Recover mnemonic phrase from an encrypted wallet:

```text
Usage: hardhat [GLOBAL OPTIONS] get-mnemonic path password

POSITIONAL ARGUMENTS:

  path          Full path where the encrypted wallet is located
  password      Password to decrypt the wallet

get-mnemonic: Recover mnemonic phrase from an encrypted wallet
```

```bash
npx hardhat get-mnemonic keystore/other.json

{
  phrase: 'public shaft female city humor annual beauty razor club mix trip blossom',
  path: "m/44'/60'/0'/0/0",
  locale: 'en'
}
```

### 1.3.6. Get Wallet Information

Recover relevant iformation from an encrypted wallet:

```text
Usage: hardhat [GLOBAL OPTIONS] get-wallet-info [--show-private] path [password]

OPTIONS:

  --show-private        set to true if you want to show the private key and mnemonic phrase

POSITIONAL ARGUMENTS:

  path          Full path where the encrypted wallet is located
  password      Password to decrypt the wallet

get-wallet-info: Recover all information from an encrypted wallet
```

```text
npx hardhat get-wallet-info keystore/example.json

    Wallet information:
      - Address: 0x47dfA49b8E6d0DF593340856F3A6a2216b77D477,
      - Public Key: 0x0477cdbd8a79163f27211c64ec6f23476a3b86b224ff011ed42cd98f40bf59fb1d05d56339099957b398d6b801079b9c88ac6501d434e95099b4c3c1501e02d80b,
      - Private Key: ***********,
      - Mnemonic: ***********
```

## 1.4. Deploy Smart contracts

The deployment of smart contracts is managed using Hardhat Tasks. It can be deployed as regular deployments or following the Transparent Proxy upgradeable pattern. The relevant information is recorded in the _deployments.json_ file at the root of project. It is recommended that this file is copied to other location to be able to access them or remember the addresses.

```text
Usage: hardhat [GLOBAL OPTIONS] deploy [--args <JSON>] --password <STRING> [--proxy-admin <STRING>] --relative-path <STRING> [--upgradeable] [contractName]

OPTIONS:

  --args                Contract initialize function's arguments if any
  --password            Password to decrypt the wallet
  --proxy-admin         Address of a deloyed Proxy Admin. Only if --upgradeable deployment
  --relative-path       Path relative to KEYSTORE.root to store the wallets
  --tx-value            Contract creation transaction value if any
  --upgradeable         Deploy as upgradeable

POSITIONAL ARGUMENTS:

  contractName  Name of the contract to deploy (default: "Example_Contract")

deploy: Deploy smart contracts on '--network'
```

### 1.4.1. Relevant Constants

- PATH_DEPLOYMENTS: defines the deployments.json file path
- PROXY_ADMIN_NAME: if for some reason you want to change the proxy admin SC name
- PROXY_ADMIN_ADDRESS: this is important. Defines the default already deployed ProxyAdmin to use in upgradeable deployments

### 1.3.2. Regular Deployment

```bash
npx hardhat deploy Lock --relative-path "/example.json" --password "PaSs_W0Rd" --args '["1662402606"]' --network ganache

    Regular contract deployed:
      - Address: 0x01b2026B2027040aC93E0C40Cd28A7262Ffa5040
      - Arguments: 1662402606
```

### 1.3.3. Upgradeable deployment

```bash
npx hardhat deploy LockUpgr --upgradeable --relative-path "/example.json" --password "PaSs_W0Rd" --args '["1662402606"]' --network ganache

WARN: no proxy admin provided, deploying new Proxy Admin

    Upgradeable contract deployed:
      - Proxy Admin: 0xc50933547aEf3a0EA766897f8D7D8F7243e342b4,
      - Proxy: 0x00Be6D2b46b5Ea72F3e9a3Afec1429C63EB47F21,
      - Logic: 0x01B3E77F9f4b7FA8E125eEC5b2f8c3EB14cA3b27
      - Arguments: 1662402606
```

### 1.3.4. Upgrade deployed Smart Contract

```text
Usage: hardhat [GLOBAL OPTIONS] upgrade [--args <JSON>] --password <STRING> [--proxy <STRING>] [--proxy-admin <STRING>] --relative-path <STRING> [contractName]

OPTIONS:

  --args                Contract initialize function's arguments if any 
  --password            Password to decrypt the wallet 
  --proxy               Address of the TUP proxy 
  --proxy-admin         Address of a deloyed Proxy Admin 
  --relative-path       Path relative to KEYSTORE.root to store the wallets 

POSITIONAL ARGUMENTS:

  contractName  Name of the contract to deploy (default: "Example_Storage")

upgrade: Upgrade smart contracts on '--network'
```

```bash
npx hardhat upgrade ContractName --relative-path "/example.json" --password "PaSs_W0Rd" --proxy "0x00Be6D2b46b5Ea72F3e9a3Afec1429C63EB47F21" --network ganache

    Contract upgraded:
      - Proxy Admin: 0xc50933547aEf3a0EA766897f8D7D8F7243e342b4,
      - Proxy: 0x00Be6D2b46b5Ea72F3e9a3Afec1429C63EB47F21,
      - Previous Logic: 0x01B3E77F9f4b7FA8E125eEC5b2f8c3EB14cA3b27
      - New Logic: 0x5E0f18F0f36e4FB17CDe93f3f7faaf9073356e25
      - Arguments:
```

## 1.4. Unit Test

There is one unit test for each Smart Contract located in "test/{ContractName}.test.ts". It's tested the deployment, initialization and behavior. By default it does not store wallets.
