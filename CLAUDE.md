# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Table of Contents

- [Essential Commands](#essential-commands)
- [Project Overview](#project-overview)
- [Smart Contract Architecture](#smart-contract-architecture)
- [Development Guidelines](#development-guidelines)
- [Testing Strategy](#testing-strategy)
- [PGP Commit Signing](#pgp-commit-signing)

## Essential Commands

### Building and Testing
```bash
# Build contracts
forge build

# Run all tests
forge test

# Run tests with coverage
forge coverage

# Run specific test file
forge test --match-path test/DidManager.t.sol

# Run specific test function
forge test --match-test testCreateDid

# Deploy to local network (dry run)
forge script script/DidManager.s.sol:DidManagerScript --sig "deploy(bool,string,bool)" false "Local_Test" false

# Deploy with broadcast
forge script script/DidManager.s.sol:DidManagerScript --sig "deploy(bool,string,bool)" true "DidManager_Test" true --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### Development Workflow
```bash
# Check gas usage
forge test --gas-report

# Format code
forge fmt

# Lint/analyze
forge build --extra-output storageLayout
```

## Project Overview

SSIoBC-did is a research implementation of a fully on-chain Decentralized Identifier (DID) management system that maintains W3C compliance while enabling smart contract interoperability. This is PhD research on creating the first complete on-chain DID document management system.

### Key Features
- **Full on-chain storage** (unlike ERC-1056 event-based approach)
- **Gas-optimized** hash-based list architecture using EnumerableSet
- **Multi-method support** (3-level deep DID methods: `did:method0:method1:method2:id`)
- **4-year expiration** with reuse capability
- **W3C DID specification compliance**

## Smart Contract Architecture

### Four-Contract System

The system consists of four main contracts working together:

1. **DidManager.sol** - Core DID lifecycle management (inherits from VMStorage and ServiceStorage)
2. **VMStorage.sol** - Verification Methods storage with hash-based lists
3. **ServiceStorage.sol** - Service endpoints storage with hash-based approach  
4. **W3CResolver.sol** - W3C-compliant document translation (optional on-chain resolution)

### Key Design Patterns

- **Abstract Storage Contracts**: VMStorage and ServiceStorage are abstract contracts inherited by DidManager
- **EnumerableSet Usage**: Efficient O(1) operations for add/remove/contains on VM and Service IDs
- **Hash-Based Indexing**: Uses `keccak256(abi.encodePacked(namespace, id))` for unique identification
- **Position-Hash Mapping**: Special mapping for VM validation using position hashes
- **Multi-level Method Support**: DIDs structured as `did:method0:method1:method2:id` with 10-byte method segments

### DID Structure
- **Methods**: bytes32 containing three 10-byte method identifiers (default: "lzpf::main::")
- **ID**: bytes32 generated from `keccak256(methods, random, tx.origin, block.prevrandao)`
- **Hash**: Internal hash calculated as `keccak256(methods, id)` for storage indexing

### Verification Methods (VMs)
- Support multiple relationship types (authentication, assertion, key agreement, etc.)
- Stored with EnumerableSet for efficient enumeration
- Include expiration timestamps and ethereum address validation
- Support publicKeyMultibase, blockchainAccountId, or ethereumAddress

### Controller System
- Fixed-length array of 5 controllers maximum (CONTROLLERS_MAX_LENGTH = 5)
- Self-sovereign by default (empty controllers = owner controls)
- Can delegate control to other DIDs with optional VM specification

## Development Guidelines

### File Organization

#### Temporary Files (.temp/ folder)
- **Always** generate non-code related files in `.temp/` folder
- **Examples**: size comparisons, gas reports, analysis outputs, deployment logs, coverage reports
- **Benefits**: Keeps repository clean while preserving local development artifacts
- **Pattern**: `.temp/analysis/`, `.temp/reports/`, `.temp/logs/` for organized sub-structure
- **Git**: Excluded from version control but preserved locally

#### Project Structure Guidelines
- Follow consolidation over proliferation principle
- Permanent files: Source code, tests, documentation, configuration
- Temporary files: Analysis results, comparison outputs, build artifacts, logs

### Code Conventions
- Use Solidity 0.8.24 (configured in foundry.toml)
- Follow existing naming patterns (snake_case for internal functions, camelCase for public)
- Use custom errors instead of require statements for gas optimization
- Maintain >90% test coverage
- Include natspec documentation for public functions

### Testing Patterns
- Use `SharedTest.sol` as base class for common test utilities
- Test files follow `ContractName.t.sol` naming convention
- Create DID helper function: `_createDid(methods, random, vmId)`
- Event testing using `vm.recordLogs()` and log analysis
- Use constants for test values (DEFAULT_RANDOM_0, DEFAULT_VM_TYPE, etc.)

### Gas Optimization Focus
- Hash-based storage instead of arrays where possible
- EnumerableSet for efficient set operations
- Minimal storage reads/writes in loops
- Immutable architecture (no upgradeable proxies)

## Testing Strategy

### Test Structure
- **SharedTest.sol**: Base class with common utilities and constants
- **DidManager.t.sol**: Core DID management functionality
- **VMStorage.t.sol**: Verification method storage operations
- **ServiceStorage.t.sol**: Service endpoint storage operations
- **W3CResolver.t.sol**: W3C compliance and resolution testing

### Coverage Requirements
- Maintain >90% test coverage (tracked across versions v0.1.2→v0.8.0)
- Test both success and failure cases
- Include edge cases for gas optimization validation
- Test expiration scenarios and cleanup functions

### Test Utilities
Use helper functions from SharedTest:
- `_createDid()`: Creates DID and returns event data
- `_createVm()`: Creates verification method and returns results
- Constants for test data (DEFAULT_RANDOM_*, DEFAULT_VM_*, etc.)

## PGP Commit Signing

Always use PGP signatures when committing:
```bash
git commit -S -m "commit message"
```

Ensure your GPG key is properly configured:
```bash
git config --global user.signingkey YOUR_GPG_KEY_ID
git config --global commit.gpgsign true
```
- Do not store security risky information in CLAUDE.md and .memories.json (MCP memories)