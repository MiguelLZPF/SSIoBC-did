# Contributing to SSIoBC-DID

Thank you for your interest in contributing to SSIoBC-DID. This document provides guidelines and instructions for contributing.

## Table of Contents

- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Commit Guidelines](#commit-guidelines)
- [Getting Help](#getting-help)

## Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (v1.5.1 or later)
- [Git](https://git-scm.com/) with GPG signing configured
- [pre-commit](https://pre-commit.com/) (optional but recommended)

### Getting Started

1. Fork the repository on GitHub.

2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/SSIoBC-did.git
   cd SSIoBC-did
   ```

3. Install dependencies:
   ```bash
   forge install
   ```

4. Install pre-commit hooks (optional):
   ```bash
   pre-commit install
   ```

5. Verify the setup:
   ```bash
   forge build
   forge test
   ```

## Pull Request Process

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. Make your changes following the [Coding Standards](#coding-standards).

3. Ensure all tests pass and coverage remains above 90%:
   ```bash
   forge test
   forge coverage
   ```

4. Format your code:
   ```bash
   forge fmt
   ```

5. Commit with a signed, conventional commit message (see [Commit Guidelines](#commit-guidelines)).

6. Push and open a pull request against `main`.

7. Ensure CI checks pass (build, test, coverage, formatting, security analysis).

## Coding Standards

### Solidity

- **Version**: Solidity 0.8.33 (fixed pragma for source, range pragma for tests)
- **Error Handling**: Use custom errors instead of `require` strings (gas optimization)
- **Naming**: `camelCase` for public functions/variables, `_camelCase` for internal/private, `UPPER_CASE` for constants
- **NatSpec**: Required for all public and external functions (`@notice`, `@param`, `@return`)
- **Types**: Use explicit types (`uint256` instead of `uint`, `int256` instead of `int`)
- **Line Length**: 120 characters maximum
- **Indentation**: 2 spaces

### Gas Optimization

- Use hash-based storage with `HashUtils` library instead of arrays where possible
- Use `EnumerableSet` for efficient set operations
- Cache storage reads in local variables to avoid redundant SLOADs
- Use unchecked arithmetic when overflow is impossible
- Prefer direct storage reads with early exit over memory copies

### Architecture

- **Immutable contracts**: No proxies or upgrade patterns
- **Abstract storage**: VMStorage/VMStorageNative and ServiceStorage are abstract contracts
- **Shared utilities**: Use existing `HashUtils` and `W3CResolverUtils` libraries

## Testing Requirements

### Structure

Tests are organized by category:

```
test/
  unit/           # Unit tests for individual contracts
  fuzz/           # Fuzz tests with randomized inputs
  invariant/      # Invariant tests for system-wide properties
  integration/    # Integration and end-to-end tests
  performance/    # Gas benchmarks
  stress/         # Stress and edge-case tests
  helpers/        # Shared test utilities and base contracts
```

### Requirements

- All new features must include unit tests
- Coverage must remain above 90% across all source contracts
- Test file naming: `ContractName.category.t.sol` (e.g., `DidManager.unit.t.sol`)
- Inherit from `TestBase` or `TestBaseNative` for shared utilities
- Use existing helpers: `_createDid()`, `_createVm()`, etc.
- Test both success and revert cases using custom error selectors

### Running Tests

```bash
# All tests
forge test

# Specific file
forge test --match-path test/unit/DidManager.unit.t.sol

# Specific function
forge test --match-test testCreateDid

# With verbosity
forge test -vvv

# Coverage report
forge coverage
```

## Commit Guidelines

### Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]
```

**Types**: `feat`, `fix`, `test`, `docs`, `refactor`, `perf`, `chore`, `ci`

**Scopes**: `did-manager`, `vm-storage`, `resolver`, `service`, `native`, `tests`, `ci`

### Examples

```
feat(native-vm): add publicKeyMultibase support for keyAgreement
fix(resolver): correct relationship bitmask for capabilityDelegation
test(did-manager): add controller reactivation edge case tests
docs: update README with deployment instructions
```

### GPG Signing

All commits must be GPG-signed:

```bash
git commit -S -m "type(scope): description"
```

## Getting Help

- Read the [PROJECT.md](./PROJECT.md) for detailed architecture documentation
- Check existing [issues](https://github.com/MiguelLZPF/SSIoBC-did/issues) for related discussions
- For security vulnerabilities, see [SECURITY.md](./SECURITY.md)
