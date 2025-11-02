# AGENTS.md - Task Executor Instructions (GitHub Copilot)

This file provides coding standards and actionable instructions for GitHub Copilot when working in the SSIoBC DID Manager repository.

## Table of Contents

- [Copilot Scope & Role](#copilot-scope--role)
- [Project Context](#project-context)
- [Solidity Development Standards](#solidity-development-standards)
- [Testing Patterns](#testing-patterns)
- [Gas Optimization Focus](#gas-optimization-focus)
- [Security Requirements](#security-requirements)
- [Code Organization](#code-organization)
- [Documentation Standards](#documentation-standards)
- [Task Execution Examples](#task-execution-examples)

## Copilot Scope & Role

### I Handle: Well-Defined, Time-Bounded, Actionable Tasks

**My role** is to execute well-defined tasks that have:
- **Clear start and end** - Specific, bounded scope
- **Minimal context needed** - Can be done with code standards alone
- **Actionable in time** - Can be completed without extensive investigation

**What I handle**:
- Code formatting and linting (`forge fmt`)
- Test scaffolding and boilerplate
- Simple code generation (getters, setters, standard patterns)
- Documentation generation (NatSpec comments, inline docs)
- Repetitive code tasks (adding similar functions across files)
- Standard implementations (following established patterns)

**What I DON'T handle**:
- Research tasks (that's Gemini via GEMINI.md)
- Task orchestration and routing (that's Claude via CLAUDE.md)
- Complex architectural decisions (that's Claude)
- Security audits (that's blockchain-code-assassin agent)

**Trigger scenarios for my invocation**:
- "Format all Solidity files"
- "Add NatSpec to this function"
- "Create test scaffolding for this contract"
- "Generate getter functions for these state variables"

## Project Context

### Quick Facts (Reference PROJECT.md for Complete Details)

- **Project**: SSIoBC-did - W3C-compliant fully on-chain DID management system
- **Language**: Solidity 0.8.24 (fixed version)
- **Framework**: Foundry (Forge, Cast, Anvil)
- **Coverage**: >90% requirement
- **Architecture**: 4 contracts (DidManager, VMStorage, ServiceStorage, W3CResolver)

**For complete architecture, DID structure, and design patterns → See PROJECT.md**

### Key Architecture (Brief Summary)

**Four-Contract System**:
1. **DidManager.sol** - Core DID lifecycle (inherits VMStorage + ServiceStorage)
2. **VMStorage.sol** - Verification methods storage (abstract contract)
3. **ServiceStorage.sol** - Service endpoints storage (abstract contract)
4. **W3CResolver.sol** - W3C DID document resolution

**Storage Approach**: Hash-based lists using OpenZeppelin's EnumerableSet for O(1) operations

**Key Patterns**: Immutable architecture, custom errors, abstract storage contracts

## Solidity Development Standards

### Language Version

- **Solidity**: 0.8.24 (fixed version, no ranges)
- **Pragma**: Use `pragma solidity 0.8.24;` exactly
- **Rationale**: Deterministic builds, consistent gas costs

### Error Handling

✅ **Use Custom Errors** (gas optimization):
```solidity
// ✅ CORRECT - Saves ~50-100 gas per revert
error InvalidDid();
error DidExpired(uint256 expirationTime);
error NotDidOwner(address caller, address owner);

if (didInfo.expirationTime < block.timestamp) {
    revert DidExpired(didInfo.expirationTime);
}
```

❌ **Avoid require with strings**:
```solidity
// ❌ AVOID - Expensive string storage
require(didInfo.expirationTime >= block.timestamp, "DID expired");
```

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Public Functions | camelCase | `createDid`, `updateVm` |
| Internal/Private Functions | _camelCase | `_validateDid`, `_generateId` |
| State Variables | camelCase | `didInfo`, `vmStorage` |
| Constants | UPPER_CASE | `EXPIRATION_TIME`, `CONTROLLERS_MAX_LENGTH` |
| Structs | PascalCase | `DidInfo`, `VerificationMethod` |
| Errors | PascalCase | `InvalidDid`, `DidExpired` |
| Events | PascalCase | `DidCreated`, `VmAdded` |

### Code Organization Pattern

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Imports (organized: external → local)
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDidManager} from "./interfaces/IDidManager.sol";
import {VMStorage} from "./VMStorage.sol";

/// @title ContractName
/// @notice High-level description for users
/// @dev Implementation details for developers
contract ContractName is VMStorage {
    // Type declarations
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // State variables (visibility order: public → internal → private)
    uint256 public constant EXPIRATION_TIME = 4 * 365 days;
    uint256 internal _didCount;
    mapping(bytes32 => DidInfo) private _dids;

    // Events
    event DidCreated(bytes32 indexed didHash, address indexed owner);
    event DidDeactivated(bytes32 indexed didHash);

    // Errors
    error InvalidDid();
    error DidExpired(uint256 expirationTime);

    // Modifiers
    modifier onlyDidOwner(bytes32 didHash) {
        if (_dids[didHash].owner != msg.sender) {
            revert NotDidOwner(msg.sender, _dids[didHash].owner);
        }
        _;
    }

    // Functions (visibility order: constructor → external → public → internal → private)

    constructor() {
        // initialization
    }

    // External functions

    // Public functions

    // Internal functions

    // Private functions
}
```

### Storage Optimization

#### Variable Packing

Group variables by type to save storage slots:

```solidity
// ✅ GOOD - 1 storage slot (32 bytes)
uint128 public value1;  // 16 bytes
uint128 public value2;  // 16 bytes

// ❌ BAD - 2 storage slots (64 bytes)
uint256 public value1;  // 32 bytes (only using 16)
uint256 public value2;  // 32 bytes (only using 16)
```

#### Immutable vs Constant

```solidity
// Use immutable for constructor-assigned values
address public immutable OWNER;
uint256 public immutable DEPLOYMENT_TIME;

constructor(address _owner) {
    OWNER = _owner;
    DEPLOYMENT_TIME = block.timestamp;
}

// Use constant for compile-time values
uint256 public constant EXPIRATION_TIME = 4 * 365 days;
uint256 public constant CONTROLLERS_MAX_LENGTH = 5;
```

### Code Formatting

**Formatter**: Foundry's `forge fmt` (configured in `foundry.toml`)

**Key Settings**:
- **Indentation**: 2 spaces (project preference)
- **Quotes**: Double quotes for strings
- **Line Length**: 120 characters max
- **Integer Types**: Explicit (uint256, int256 not uint, int)
- **Bracket Spacing**: Yes for imports/function calls
- **Import Ordering**: Manual (external → local)

**Running**:
```bash
# Format all files
forge fmt

# Format specific file
forge fmt src/DidManager.sol

# Check without modifying
forge fmt --check
```

## Testing Patterns

### Test File Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SharedTest} from "./helpers/SharedTest.sol";
import {DidManager} from "../src/DidManager.sol";

/// @title DidManager Test Suite
contract DidManagerTest is SharedTest {
    DidManager public didManager;

    function setUp() public {
        didManager = new DidManager();
    }

    // Success case tests
    function testCreateDid() public {
        // Test implementation
    }

    // Failure case tests
    function testCreateDidRevertsWhenMethodsInvalid() public {
        vm.expectRevert(DidManager.InvalidMethods.selector);
        didManager.createDid(bytes32(0), DEFAULT_RANDOM_0, DEFAULT_VM_ID_0);
    }

    // Fuzz tests
    function testFuzzCreateDid(bytes32 methods, bytes32 random) public {
        vm.assume(methods != bytes32(0));
        // Fuzz test implementation
    }
}
```

### Test Naming Conventions

| Test Type | Pattern | Example |
|-----------|---------|---------|
| Success | `testFunctionName()` | `testCreateDid()` |
| Failure | `testFunctionNameRevertsWhen[Condition]()` | `testCreateDidRevertsWhenMethodsInvalid()` |
| Fuzz | `testFuzzFunctionName(args)` | `testFuzzCreateDid(bytes32 methods)` |
| Integration | `testIntegration[Scenario]()` | `testIntegrationDidLifecycle()` |

### Test Coverage Requirements

- **Minimum**: >90% overall coverage
- **Critical Paths**: 100% for security-critical functions
- **Edge Cases**: Boundary conditions (zero values, max values, overflow)
- **Failure Cases**: All revert conditions tested

### Using Test Helpers

From `SharedTest.sol`:

```solidity
// Create DID with default values
(bytes32 didHash, address owner, bytes32 vmId) = _createDid(
    DEFAULT_METHODS,
    DEFAULT_RANDOM_0,
    DEFAULT_VM_ID_0
);

// Create verification method
(bytes32 vmHash, bytes32 vmId) = _createVm(
    didHash,
    DEFAULT_METHODS,
    DEFAULT_ID,
    DEFAULT_VM_TYPE,
    DEFAULT_PUBLIC_KEY_MULTIBASE
);

// Constants available
DEFAULT_METHODS
DEFAULT_RANDOM_0
DEFAULT_VM_ID_0
DEFAULT_VM_TYPE
DEFAULT_PUBLIC_KEY_MULTIBASE
```

### Event Testing

```solidity
function testEventEmission() public {
    // Record logs
    vm.recordLogs();

    // Perform action
    (bytes32 didHash,) = didManager.createDid(
        DEFAULT_METHODS,
        DEFAULT_RANDOM_0,
        DEFAULT_VM_ID_0
    );

    // Get recorded logs
    Vm.Log[] memory logs = vm.getRecordedLogs();

    // Verify event (first event in logs)
    assertEq(logs[0].topics[0], keccak256("DidCreated(bytes32,address)"));
    assertEq(logs[0].topics[1], didHash);
}
```

## Gas Optimization Focus

### Priority Techniques

#### 1. Hash-Based Storage (vs Arrays)

```solidity
// ✅ OPTIMIZED - O(1) operations
mapping(bytes32 => DidInfo) private _dids;
EnumerableSet.Bytes32Set private _didSet;

// ❌ EXPENSIVE - O(n) operations
DidInfo[] private _didArray;  // Costly iteration, no efficient lookup
```

**Gas Savings**: ~20,000 gas per lookup in large datasets

#### 2. Storage Caching

```solidity
// ✅ GOOD - Single SLOAD (2100 gas cold, 100 gas warm)
DidInfo memory didInfo = _dids[didHash];
if (didInfo.owner == address(0)) revert InvalidDid();
if (didInfo.expirationTime < block.timestamp) revert DidExpired();

// ❌ BAD - Multiple SLOADs (4200 gas cold, 200 gas warm)
if (_dids[didHash].owner == address(0)) revert InvalidDid();
if (_dids[didHash].expirationTime < block.timestamp) revert DidExpired();
```

**Gas Savings**: ~2000 gas per avoided SLOAD

#### 3. Unchecked Arithmetic (When Safe)

```solidity
// ✅ WHEN SAFE - No overflow possible
unchecked {
    for (uint256 i = 0; i < array.length; ++i) {
        // loop body
    }
}
```

**Gas Savings**: ~50-100 gas per iteration

#### 4. Custom Errors vs Require Strings

```solidity
// ✅ SAVES GAS - ~50-100 gas per revert
error InvalidDid();
if (condition) revert InvalidDid();

// ❌ COSTS MORE
require(condition, "Invalid DID");
```

#### 5. EnumerableSet for Set Operations

```solidity
using EnumerableSet for EnumerableSet.Bytes32Set;

EnumerableSet.Bytes32Set private _vmIds;  // O(1) add/remove/contains

// Usage
_vmIds.add(vmId);        // O(1)
_vmIds.remove(vmId);     // O(1)
_vmIds.contains(vmId);   // O(1)
_vmIds.length();         // O(1)
_vmIds.at(index);        // O(1)
```

### Gas Testing

```bash
# Generate gas report
forge test --gas-report

# Output includes per-function gas costs
# Update docs/metrics/gas-costs-*.md for significant changes
```

## Security Requirements

### Immutable Architecture

- **No Proxy Patterns**: Direct implementation only
- **No Upgradeable Contracts**: Design for permanence
- **Fixed Dependencies**: Pinned OpenZeppelin versions

**Rationale**: Security and predictability over upgradeability

### Access Control Pattern

```solidity
modifier onlyDidOwner(bytes32 didHash) {
    if (_dids[didHash].owner != msg.sender) {
        revert NotDidOwner(msg.sender, _dids[didHash].owner);
    }
    _;
}

function updateDid(bytes32 didHash, ...) external onlyDidOwner(didHash) {
    // Only DID owner can call this
}
```

### Input Validation

**Always validate inputs on public/external functions**:

```solidity
function createDid(
    bytes32 methods,
    bytes32 random,
    bytes32 vmId
) external returns (bytes32 didHash, bytes32 id) {
    // Validate all inputs
    if (methods == bytes32(0)) revert InvalidMethods();
    if (vmId == bytes32(0)) revert InvalidVmId();

    // ... implementation
}
```

### Checks-Effects-Interactions Pattern

```solidity
function withdraw() external {
    // 1. CHECKS - Validate conditions
    uint256 amount = balances[msg.sender];
    if (amount == 0) revert InsufficientBalance();

    // 2. EFFECTS - Update state BEFORE external calls
    balances[msg.sender] = 0;

    // 3. INTERACTIONS - External calls LAST
    (bool success,) = msg.sender.call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

### Security Checklist

Before committing code, verify:

- ✅ Input validation on all public/external functions
- ✅ Access control modifiers where appropriate
- ✅ Checks-Effects-Interactions pattern for state changes
- ✅ Custom errors for gas efficiency
- ✅ Immutable variables where possible
- ✅ No delegatecall vulnerabilities
- ✅ No unchecked external calls (check return values)
- ✅ No timestamp manipulation vulnerabilities
- ✅ No reentrancy vulnerabilities

## Code Organization

### Contract Structure

```
DidManager.sol (inherits VMStorage + ServiceStorage)
    ↓
VMStorage.sol (abstract - verification methods)
ServiceStorage.sol (abstract - service endpoints)
```

### File Organization

```
src/
├── DidManager.sol          # Core DID lifecycle
├── VMStorage.sol           # Verification methods (abstract)
├── ServiceStorage.sol      # Service endpoints (abstract)
├── W3CResolver.sol         # W3C DID document resolution
└── interfaces/
    ├── IDidManager.sol
    ├── IVMStorage.sol
    ├── IServiceStorage.sol
    └── IW3CResolver.sol

test/
├── unit/                   # Unit tests
├── integration/            # Integration tests
├── fuzz/                   # Fuzz tests
├── invariant/              # Invariant tests
├── performance/            # Gas benchmarks
├── stress/                 # Stress tests
└── helpers/
    ├── TestBase.sol
    ├── DidTestHelpers.sol
    └── Fixtures.sol
```

### Import Organization

```solidity
// 1. External dependencies (OpenZeppelin, etc.)
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// 2. Local interfaces
import {IDidManager} from "./interfaces/IDidManager.sol";

// 3. Local contracts
import {VMStorage} from "./VMStorage.sol";
```

## Documentation Standards

### NatSpec Requirements

**All public and external functions MUST include NatSpec**:

```solidity
/// @notice Creates a new DID with initial verification method
/// @dev Generates didHash from keccak256(methods, id). ID is generated from
///      keccak256(methods, random, tx.origin, block.prevrandao)
/// @param methods The DID method bytes (3x10 bytes for method0:method1:method2)
/// @param random Random bytes for ID generation (user-provided entropy)
/// @param vmId Initial verification method identifier
/// @return didHash The hash of the created DID (used as storage key)
/// @return id The generated DID identifier (unique per DID)
function createDid(
    bytes32 methods,
    bytes32 random,
    bytes32 vmId
) external returns (bytes32 didHash, bytes32 id);
```

### NatSpec Tags

| Tag | Usage | Required |
|-----|-------|----------|
| `@title` | Contract title | Yes (contracts) |
| `@author` | Author name | Optional |
| `@notice` | User-facing description | Yes (public/external) |
| `@dev` | Developer details | Recommended |
| `@param` | Parameter description | Yes (if has params) |
| `@return` | Return value description | Yes (if returns) |
| `@inheritdoc` | Inherit docs from interface | Yes (if implementing) |

### Inline Comments

```solidity
// Use clear, concise comments for complex logic
// Explain WHY, not WHAT (code shows what)

// ✅ GOOD - Explains reasoning
// Use block.prevrandao for post-merge randomness (replaces block.difficulty)
bytes32 id = keccak256(abi.encodePacked(methods, random, tx.origin, block.prevrandao));

// ❌ BAD - States the obvious
// Hash the parameters
bytes32 id = keccak256(abi.encodePacked(methods, random, tx.origin, block.prevrandao));
```

## Task Execution Examples

### Example 1: Format Code

**Task**: "Format all Solidity files"

**Execution**:
```bash
forge fmt
```

**Expected Output**: All .sol files formatted according to foundry.toml config

### Example 2: Add NatSpec

**Task**: "Add NatSpec documentation to the updateVm function"

**Execution**:
```solidity
/// @notice Updates an existing verification method
/// @dev Requires sender to be DID owner. VM must exist and be active
/// @param didHash The DID hash containing the VM
/// @param vmId The verification method identifier
/// @param newVmType The new VM type (e.g., "EcdsaSecp256k1VerificationKey2019")
/// @param newPublicKey The new public key in multibase format
function updateVm(
    bytes32 didHash,
    bytes32 vmId,
    string memory newVmType,
    string memory newPublicKey
) external onlyDidOwner(didHash);
```

### Example 3: Create Test Scaffolding

**Task**: "Create test scaffolding for ServiceStorage contract"

**Execution**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SharedTest} from "./helpers/SharedTest.sol";
import {ServiceStorage} from "../src/ServiceStorage.sol";

contract ServiceStorageTest is SharedTest {
    ServiceStorage public serviceStorage;

    function setUp() public {
        // Setup code
    }

    function testAddService() public {
        // Test add service
    }

    function testAddServiceRevertsWhenInvalid() public {
        // Test failure case
    }

    function testRemoveService() public {
        // Test remove service
    }
}
```

### Example 4: Generate Getter Functions

**Task**: "Generate getter functions for DID info fields"

**Execution**:
```solidity
/// @notice Returns the owner of a DID
/// @param didHash The DID hash
/// @return owner The address of the DID owner
function getDidOwner(bytes32 didHash) external view returns (address owner) {
    return _dids[didHash].owner;
}

/// @notice Returns the expiration time of a DID
/// @param didHash The DID hash
/// @return expirationTime The timestamp when DID expires
function getDidExpirationTime(bytes32 didHash) external view returns (uint256 expirationTime) {
    return _dids[didHash].expirationTime;
}
```

---

**Last Updated**: 2025-01-02
**Purpose**: Task executor instructions for GitHub Copilot
**Role**: Execute well-defined, time-bounded, actionable tasks
**For**: GitHub Copilot code assistance in SSIoBC DID Manager project
**Coverage Target**: >90% test coverage
**Solidity Version**: 0.8.24 (fixed)
**Framework**: Foundry
