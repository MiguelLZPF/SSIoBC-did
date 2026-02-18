# Self-Sovereign Identity Over BlockChain [SSIoBC-DID]

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.33-363636.svg)](https://soliditylang.org/)
[![Tests](https://img.shields.io/badge/Tests-296_passing-brightgreen.svg)](#quick-start)
[![Coverage](https://img.shields.io/badge/Coverage->90%25-brightgreen.svg)](#quick-start)
[![W3C DID Core](https://img.shields.io/badge/W3C-DID_Core_v1.0-005A9C.svg)](https://www.w3.org/TR/did-core/)

W3C-compliant fully on-chain DID management system built with Solidity and the Foundry framework. This is the first complete on-chain DID document storage implementation, as opposed to event-based reconstruction approaches used by existing solutions.

## Table of Contents

- [Project Overview](#project-overview)
- [Dual-Variant Architecture](#dual-variant-architecture)
- [Contract Architecture](#contract-architecture)
- [Quick Start](#quick-start)
- [Creating a New DID](#creating-a-new-did)
- [Deployment](#deployment)
- [Advantages](#advantages)
- [Citation](#citation)
- [Contributing](#contributing)
- [License](#license)

## Project Overview

This project focuses on the creation and management of Decentralized Identifiers (DIDs) using a dual-variant smart contract architecture. DIDs provide a decentralized and self-sovereign identity solution, allowing individuals and entities to have control over their digital identities.

The system stores complete DID documents on-chain (not just events), enabling direct resolution without off-chain indexing. All contracts comply with [W3C DID Core v1.0](https://www.w3.org/TR/did-core/).

## Dual-Variant Architecture

The system provides two deployment variants sharing a common base:

### Full W3C Variant (multi-key, multi-type)

Supports arbitrary key types, public key formats, and blockchain account IDs.

### Ethereum-Native Variant (single-key, Ethereum-only)

Optimized for Ethereum addresses only. Stores each VM in a single 32-byte storage slot and derives W3C fields (type, publicKeyMultibase, blockchainAccountId) at resolution time.

## Contract Architecture

### Source Contracts (9 files)

| Contract | Description |
|----------|-------------|
| **DidManager.sol** | Full W3C DID lifecycle management |
| **DidManagerNative.sol** | Ethereum-native DID lifecycle management |
| **DidManagerBase.sol** | Shared abstract base (expiration, controllers) |
| **VMStorage.sol** | Full W3C verification method storage (multi-slot) |
| **VMStorageNative.sol** | Native VM storage (1-slot per VM) |
| **ServiceStorage.sol** | Shared service endpoints storage |
| **HashUtils.sol** | Shared hash utility library |
| **W3CResolver.sol** | Full W3C DID document resolution |
| **W3CResolverNative.sol** | Native DID document resolution with field derivation |

### Interfaces (6 files)

`IDidManager`, `IDidManagerNative`, `IVMStorage`, `IVMStorageNative`, `IServiceStorage`, `IW3CResolver`

### Inheritance Structure

```
DidManager       = VMStorage       + DidManagerBase + ServiceStorage
DidManagerNative = VMStorageNative + DidManagerBase + ServiceStorage
```

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed

### Build and Test

```bash
# Build contracts
forge build

# Run all tests (296 tests, >90% coverage)
forge test

# Run tests with coverage report
forge coverage

# Run specific test file
forge test --match-path test/unit/DidManager.unit.t.sol

# Gas report
forge test --gas-report

# Format code
forge fmt
```

## Creating a New DID

The DID structure follows the format:

```
did:method0:method1:method2:id
```

1. Call `createDid` with method identifiers and a random value (defaults provided if omitted)
2. A unique DID ID is generated from `keccak256(methods, random, tx.origin, block.prevrandao)`
3. The initial verification method is created and linked to the DID
4. The VM owner validates it by calling `validateVm` (proves address ownership)
5. The DID document can be resolved via the W3CResolver contract

## Deployment

1. Configure environment variables in a `.env` file (see [`.env.example`](./.env.example)).

2. Build the contracts:
   ```bash
   forge build
   ```

3. Deploy using the Foundry script:
   ```bash
   # Dry run (no broadcast)
   forge script script/DidManager.s.sol:DidManagerScript \
     --sig "deploy(bool,string,bool)" false "Local_Test" false

   # Deploy with broadcast
   forge script script/DidManager.s.sol:DidManagerScript \
     --sig "deploy(bool,string,bool)" true "DidManager_Deploy" true \
     --rpc-url http://localhost:8545 \
     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
     --broadcast
   ```

4. Deployment metadata is stored in `.deployments.json` when the `store` option is `true`.

## Advantages

1. **Fully On-Chain**: Complete DID documents stored on-chain, no event reconstruction needed
2. **W3C Compliant**: Full W3C DID Core v1.0 compliance
3. **Dual-Variant**: Choose between full W3C flexibility or Ethereum-native gas efficiency
4. **Gas Optimized**: Hash-based storage, EnumerableSet, storage packing, custom errors
5. **Self-Sovereign**: DID owners control their identity without central authorities
6. **Immutable Architecture**: No proxies or upgradability, reducing attack surface

For detailed architecture documentation, see [PROJECT.md](./PROJECT.md).

## Citation

If you use this software in your research, please cite it using the metadata in [CITATION.cff](./CITATION.cff).

### Software Citation (BibTeX)

```bibtex
@software{lopezfernandez2026ssiobc_did,
  author       = {Lopez Fernandez, Miguel Angel},
  title        = {{SSIoBC-DID}: Self-Sovereign Identity Over BlockChain -- Decentralized Identifiers},
  year         = {2026},
  url          = {https://github.com/MiguelLZPF/SSIoBC-did},
  license      = {Apache-2.0}
}
```

### Research Paper Citation

```bibtex
@article{gomezcarpena2026ssiobc,
  author  = {G\'{o}mez Carpena, Miguel},
  title   = {[USER_TO_PROVIDE: Paper Title]},
  journal = {[USER_TO_PROVIDE: Journal Name]},
  year    = {2026},
  doi     = {[USER_TO_PROVIDE]}
}
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on how to contribute, including coding standards, testing requirements, and the pull request process.

For security vulnerabilities, please see [SECURITY.md](./SECURITY.md).

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

**Dependencies:**
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - MIT License
- [Forge Std](https://github.com/foundry-rs/forge-std) - MIT/Apache-2.0 License
