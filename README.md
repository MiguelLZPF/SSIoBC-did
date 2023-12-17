# 1. Self-Sovereign Identity Over BlockChain [SSIoBC-DID]

Before running anything, make sure you run `npm install`.

https://github.com/MiguelLZPF/hardhat-base

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

# Contract Architecture

This project consists of several contracts that work together to form a system. The main contracts involved are `DidManager`, `VMStorage`, and `ServiceStorage`. In this architecture, `DidManager` is the only contract accessible to addresses other than `VMStorage` or `ServiceStorage`. Let's take a closer look at each of these contracts:

## DidManager.sol
The `DidManager` contract is responsible for managing Decentralized Identifiers (DIDs). It stores DIDs in a mapping of mappings of mappings, representing the structure `did:method0:method1:method2:id`. DIDs are created using the `createDid` function, which takes method identifiers and a random value as inputs. The method identifiers can be optionally provided, and if not provided, default method identifiers are used. The `createDid` function generates a unique DID and emits a `DidCreated` event with the generated DID and the address of the caller.

## VMStorage.sol
The `VMStorage` contract is a storage contract that is only accessible to the Verification Method (VM). It provides a secure and isolated storage space for the VM to store data. The contract contains internal functions and variables that are used by the VM for storage operations. It is not directly accessible by other addresses in the system.

## ServiceStorage.sol
The `ServiceStorage` contract is another storage contract that is only accessible to a specific service in the system. Similar to `VMStorage`, it provides a dedicated storage space for the service to store data. The contract contains internal functions and variables specific to the service's storage needs. It is not directly accessible by other addresses in the system.

## System Architecture
The system architecture revolves around the `DidManager` contract, which acts as the entry point for managing DIDs. Other contracts, such as `VMStorage` and `ServiceStorage`, provide specialized storage capabilities for the Virtual Machine and a specific service, respectively. The contracts work together to enable the system's functionality, with `DidManager` coordinating the creation and management of DIDs, and the storage contracts providing secure and isolated storage spaces.