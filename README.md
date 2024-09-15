# Self-Sovereign Identity Over BlockChain [SSIoBC-DID]

Before running anything, make sure you run `npm install`.

https://github.com/MiguelLZPF/hardhat-base

- [1. Project Overview](#1-project-overview)
- [2. Contract Architecture](#2-contract-architecture)
  - [2.1. DidManager.sol](#21-didmanagersol)
  - [2.2. VMStorage.sol](#22-vmstoragesol)
  - [2.3. ServiceStorage.sol](#23-servicestoragesol)
  - [2.4. System Architecture](#24-system-architecture)
- [3. Creating a New DID](#3-creating-a-new-did)
- [4. Advantages of this Implementation](#4-advantages-of-this-implementation)
- [5. Deploy smart contracts](#5-deploy-smart-contracts)
- [6. Conclusion](#6-conclusion)

## 1. Project Overview

This project focuses on the creation and management of Decentralized Identifiers (DIDs) using the `DidManager` contract. DIDs provide a decentralized and self-sovereign identity solution, allowing individuals and entities to have control over their digital identities. This readme provides an overview of the process of creating a new DID and highlights the advantages of this implementation compared to other solutions.

## 2. Contract Architecture

This project consists of several contracts that work together to form a system. The main contracts involved are `DidManager`, `VMStorage`, and `ServiceStorage`. In this architecture, `DidManager` is the only contract accessible to addresses other than `VMStorage` or `ServiceStorage`. Let's take a closer look at each of these contracts:

### 2.1. DidManager.sol
The `DidManager` contract is responsible for managing Decentralized Identifiers (DIDs). It stores DIDs in a mapping of mappings of mappings, representing the structure `did:method0:method1:method2:id`. DIDs are created using the `createDid` function, which takes method identifiers and a random value as inputs. The method identifiers can be optionally provided, and if not provided, default method identifiers are used. The `createDid` function generates a unique DID and emits a `DidCreated` event with the generated DID and the address of the caller.

### 2.2. VMStorage.sol
The `VMStorage` contract is a storage contract that is only accessible to the Verification Method (VM). It provides a secure and isolated storage space for the VM to store data. The contract contains internal functions and variables that are used by the VM for storage operations. It is not directly accessible by other addresses in the system.

### 2.3. ServiceStorage.sol
The `ServiceStorage` contract is another storage contract that is only accessible to a specific service in the system. Similar to `VMStorage`, it provides a dedicated storage space for the service to store data. The contract contains internal functions and variables specific to the service's storage needs. It is not directly accessible by other addresses in the system.

### 2.4. System Architecture
The system architecture revolves around the `DidManager` contract, which acts as the entry point for managing DIDs. Other contracts, such as `VMStorage` and `ServiceStorage`, provide specialized storage capabilities for the Virtual Machine and a specific service, respectively. The contracts work together to enable the system's functionality, with `DidManager` coordinating the creation and management of DIDs, and the storage contracts providing secure and isolated storage spaces.

## 3. Creating a New DID

The process of creating a new DID involves calling the `createDid` function in the `DidManager` contract. Here's an overview of the steps involved:

1. Input Validation: The function validates the provided method identifiers and random value. If any of them are not provided, default values are used.

2. DID Generation: The function generates a unique DID by hashing together the method identifiers, random value, sender's address, current timestamp, miner's address, and block hash.

3. Expiration Check: The function checks if the generated DID is already in use or expired. It calls the internal `_isExpired` function to perform the check.

4. Expiration Update: If the generated DID is valid, the function updates the expiration date for the corresponding ID hash by calling the internal `_updateExpiration` function.

5. Event Emission: Finally, the function emits a `DidCreated` event with the generated DID and the address of the caller.

## 4. Advantages of this Implementation

Compared to other DID solutions, this implementation offers several advantages:

1. **Decentralization**: The system is built on a decentralized blockchain network, ensuring that DIDs are not controlled by any central authority.

2. **Self-Sovereign Identity**: Individuals and entities have full control over their DIDs, allowing them to manage and use their digital identities as they see fit.

3. **Secure Storage**: The system utilizes dedicated storage contracts (`Storage.sol` and `VMStorage.sol`) to securely store and retrieve data related to DIDs and services.

4. **Flexibility**: The `DidManager` contract provides a flexible framework for managing DIDs, allowing for customization and integration with other services in the system.

5. **Efficiency**: The use of hashed identifiers and expiration date tracking ensures efficient and reliable management of DIDs.

For more detailed information about the project structure, contracts, and functionality, please refer to the corresponding source code files in the project repository.

## 5. Deploy smart contracts

To get started with the project, follow these steps:

1. Configure the project environmental variables in a `.env` file as [`.env.example`](./.env.example).

2. Compile the contracts using the Foundry framework by running `forge build`.

3. Deploy the contracts to the desired network using the deployment scripts in the [`scripts/`](./script/) directory.

  ```bash
    # Example for deploying DidManager contract
    forge script script/DidManager.s.sol:DidManagerScript --sig "deploy(bool,string,bool)" true "DidManager_Test" true --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
  ```
  3.1 If deployed with `store` option set to `true`, the deployment information will be stored in [.last-deployment.json](./.last-deployment.json)

4. Interact with the deployed `DidManager` contract to create and manage DIDs.

## 6. Conclusion

The project provides a robust and decentralized solution for creating and managing DIDs. By leveraging the `DidManager` contract and associated contracts, users can have control over their digital identities while benefiting from secure and efficient storage capabilities. The advantages of this implementation make it a compelling choice for decentralized identity management.

For any further questions or assistance, please refer to the project documentation or reach out to the project maintainers.

**Note:** This readme provides a high-level overview of the project. For more detailed information, please refer to the project's documentation and source code files.