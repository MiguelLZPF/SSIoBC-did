# CLAUDE.md - SSIoBC-did Subproject

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context Isolation Notice

**Scope:** This file contains context ONLY for the SSIoBC-did smart contract implementation subproject.

**Context Isolation Rule:** If parent directory context (`/Users/miguel_lzpf/Projects/SSIoBC/CLAUDE.md`) is automatically loaded by Claude Code, you MUST IGNORE all parent-specific details including:
- ❌ Parent project file structure (Articles/, Diagrams/, Results/, main paper files)
- ❌ Main research paper references and version tracking
- ❌ Parent repository organization and workflows
- ❌ Cross-project file references outside this directory

**What to Keep from Global/Parent:**
- ✅ General PhD research context (academic quality standards)
- ✅ Multi-AI routing rules (global orchestration system)
- ✅ General blockchain/DID domain knowledge

**Working Directory:** `/Users/miguel_lzpf/Projects/SSIoBC/SSIoBC-did/`
**MCP Access:** Restricted to current directory only (verified via .mcp.json)

---

## Table of Contents

- [Context Isolation Notice](#context-isolation-notice)
- [Quick Facts](#quick-facts)
- [Essential Commands](#essential-commands)
- [AI Orchestration & Routing](#ai-orchestration--routing)
- [Project Knowledge Reference](#project-knowledge-reference)
- [Development Guidelines](#development-guidelines)
- [Security Guidelines](#security-guidelines)
- [File References](#file-references)

## Quick Facts

- **Project**: W3C-compliant fully on-chain DID management system
- **Innovation**: First complete on-chain DID document storage (vs event-based)
- **Language**: Solidity 0.8.33 (Foundry framework)
- **Coverage**: >90% required (enforced in CI/CD)
- **Architecture**: Dual-variant (Full W3C + Ethereum-Native) with shared DidManagerBase + ServiceStorage + HashUtils
- **Storage**: Hash-based lists with EnumerableSet (gas-optimized)
- **Standards**: W3C DID Core v1.0 compliant
- **Working Dir**: `/Users/miguel_lzpf/Projects/SSIoBC-did/`

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

# Gas report
forge test --gas-report

# Format code
forge fmt
```

### Deployment
```bash
# Deploy to local network (dry run)
forge script script/DidManager.s.sol:DidManagerScript --sig "deploy(bool,string,bool)" false "Local_Test" false

# Deploy with broadcast
forge script script/DidManager.s.sol:DidManagerScript --sig "deploy(bool,string,bool)" true "DidManager_Test" true --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

## AI Orchestration & Routing

**Global routing rules apply** (defined in `~/.claude/CLAUDE.md`).

See also:
- `~/.claude/agents/ROUTING-RULES.md` - Complete routing keywords
- `~/.claude/agents/AGENT-SELECTION-GUIDE.md` - When to use each agent

### Project-Specific Routing Overrides

For this blockchain project, the following guidelines apply:

#### Security Reviews (MANUAL ONLY)
- **@blockchain-code-assassin** is **MANUAL ONLY** (never auto-routed)
- When user requests "audit", "review contract", or "security analysis":
  - **Suggest** using @blockchain-code-assassin for comprehensive audit
  - **Wait** for user approval before invoking
  - **Do NOT** auto-route to blockchain-code-assassin

#### Solidity Code Quality
- **Formatting/linting**: Use @agent-code-worker-solidity (automatic)
- **Simple fixes**: Use @agent-code-worker-solidity (automatic)
- **Security audits**: Suggest @blockchain-code-assassin (manual, wait for approval)

#### Research Tasks
- **W3C DID specifications**: Use @agent-truth-seeker-gemini (automatic)
- **Solidity best practices**: Use @agent-truth-seeker-gemini (automatic)
- **EIP/ERC standards**: Use @agent-truth-seeker-gemini (automatic)

#### Git Operations
- **All git operations**: Use @agent-git-maestro (automatic)
- **PGP signing**: Required for all commits

### When Claude Handles Directly

Complex reasoning tasks that require Claude's capabilities:
- **Architecture Design**: Smart contract system design, pattern selection
- **Complex Debugging**: Root cause analysis, multi-layer issues
- **Strategic Decisions**: Technology choices, design patterns
- **Novel Problems**: No established patterns, requires reasoning
- **Business Logic**: DID lifecycle, controller delegation, complex state management

## Project Knowledge Reference

**Detailed project information is in PROJECT.md** - reference it for:

- Complete smart contract architecture (dual-variant system)
- DID structure and concepts (methods, ID, hash generation)
- Verification methods (VMs) and controller system
- Design patterns (hash-based storage, EnumerableSet, etc.)
- Innovation claims and comparison with existing solutions
- File organization and artifact management

**Quick Summary**:

### Dual-Variant System

**Full W3C Variant** (multi-key, multi-type):
1. **DidManager.sol** - Core DID lifecycle (inherits VMStorage, DidManagerBase, ServiceStorage)
2. **VMStorage.sol** - Verification methods storage (abstract, multi-type VMs)
3. **W3CResolver.sol** - W3C-compliant document resolution

**Ethereum-Native Variant** (single-key, Ethereum-only):
4. **DidManagerNative.sol** - Native DID lifecycle (inherits VMStorageNative, DidManagerBase, ServiceStorage)
5. **VMStorageNative.sol** - Native VM storage (abstract, 1-slot address-based VMs)
6. **W3CResolverNative.sol** - Resolution with field derivation at query time

**Shared:**
7. **DidManagerBase.sol** - Common DID logic (expiration, controllers, parameter validation helpers)
8. **ServiceStorage.sol** - Service endpoints storage (abstract contract)
9. **HashUtils.sol** - Shared hash helper library (calculateIdHash, calculatePositionHash)

### DID Structure

```
did:method0:method1:method2:id
```

- **Methods**: bytes32 with three 10-byte segments (default: "lzpf::main::")
- **ID**: Generated from `keccak256(methods, random, tx.origin, block.prevrandao)`
- **Hash**: `keccak256(methods, id)` for storage indexing

### Key Design Patterns

- **Hash-Based Storage**: O(1) operations via HashUtils library (shared by VMStorage + ServiceStorage)
- **EnumerableSet**: Efficient set operations for VMs and Services
- **Immutable Architecture**: No proxies, no upgrades
- **Custom Errors**: Gas optimization (all contracts use custom errors, no require strings)
- **Abstract Storage**: Modular VMStorage/VMStorageNative and ServiceStorage
- **Storage Caching**: Direct storage reads with early exit (e.g., _isControllerFor, _isExpired)
- **Resolution-time Derivation**: W3CResolverNative derives VM fields at query time (zero extra storage)

**See PROJECT.md for complete details**

## Development Guidelines

### File Organization

#### Temporary Files (.temp/ folder)
- **Always** generate non-code related files in `.temp/` folder
- **Examples**: Size comparisons, gas reports, analysis outputs, deployment logs
- **Pattern**: `.temp/analysis/`, `.temp/reports/`, `.temp/logs/`
- **Git**: Excluded from version control but preserved locally

#### Documentation System (docs/ folder)
- **Purpose**: Academic-quality metrics tracking and research validation
- **Structure**: `docs/metrics/` (histories), `docs/analysis/` (research), `docs/assets/` (evidence)
- **Standards**: Table of Contents required, consolidation over proliferation
- **Maintenance**: Update when significant performance changes occur

### Code Conventions

- **Solidity**: 0.8.33 (fixed version)
- **Naming**: camelCase for public, _camelCase for internal, UPPER_CASE for constants
- **Errors**: Custom errors instead of require strings (gas optimization)
- **Coverage**: >90% required
- **Natspec**: Required for all public/external functions

### Testing Patterns

- **Base Class**: Inherit from `SharedTest.sol` for common utilities
- **Naming**: `ContractName.t.sol` for test files
- **Helpers**: `_createDid()`, `_createVm()` from SharedTest
- **Constants**: Use `DEFAULT_RANDOM_*`, `DEFAULT_VM_*`, etc.
- **Events**: Test using `vm.recordLogs()` and log analysis

### Gas Optimization Focus

- Hash-based storage instead of arrays where possible (via HashUtils library)
- EnumerableSet for efficient set operations
- Storage caching (single SLOAD vs multiple, e.g., _isExpired)
- Direct storage reads with early exit (e.g., _isControllerFor avoids memory copy)
- Unchecked arithmetic when safe
- Custom errors over require strings (enforced across all contracts)
- Optimizer tuned for deployment size (optimizer_runs = 200)

### Code Formatting

**Formatter**: Foundry's `forge fmt` (configured in `foundry.toml`)

**Key Settings**:
- 2-space indentation (project preference)
- Double quotes for strings
- 120 character line length
- Explicit types (uint256, int256)
- Preserved import ordering

**Run**: `forge fmt` (or check with `forge fmt --check`)

**Pre-commit**: Automatic formatting via `.pre-commit-config.yaml`

### PGP Commit Signing

**REQUIRED** - All commits must be PGP-signed:

```bash
git commit -S -m "commit message"
```

**Ensure git config**:
```bash
git config --global user.signingkey YOUR_GPG_KEY_ID
git config --global commit.gpgsign true
```

**Always route git operations to @agent-git-maestro** for proper signing.

### Quality Thresholds

- **Coverage**: >90% minimum (enforced in CI/CD)
- **Gas Tracking**: Update `docs/metrics/gas-costs-*.md` for significant changes
- **Security**: ALL contract changes reviewed by blockchain-code-assassin
- **W3C Compliance**: Verify DID document format compliance

### Pre-commit Integration

Pre-commit hooks (`.pre-commit-config.yaml`):
- Automatic formatting via `forge fmt`
- Build validation
- (Optional) Test execution

Install: `pre-commit install`

### CI/CD Integration

GitHub Actions (`.github/workflows/ci.yml`) — single unified workflow with 7 jobs:
- **build**: Compile + EIP-170 contract size check (all jobs depend on this)
- **test**: Unit/fuzz/invariant/integration tests with `FOUNDRY_PROFILE=ci` (fuzz=256, excludes stress/performance)
- **coverage**: LCOV coverage with `FOUNDRY_PROFILE=ci`, 90% threshold + PR comment (excludes stress/performance)
- **quality**: `forge fmt --check` + `forge lint`
- **security**: Slither static analysis with SARIF upload to GitHub Security tab
- **gas-diff**: PR-only gas cost comparison via `foundry-gas-diff`
- **thorough**: Full property tests (fuzz=1000, invariant=256) + stress/performance — runs only on push to main

Two Foundry CI profiles in `foundry.toml`:
- `ci`: Fast (fuzz=256, invariant runs=64/depth=32) — PRs finish in <5 min
- `ci_thorough`: Deep (fuzz=1000, invariant runs=256/depth=64) — main merges only

Foundry version pinned to `v1.5.1`. Dependabot keeps action versions updated weekly.

## Security Guidelines

### DID/SSI Project Security Considerations

When developing or reviewing smart contracts for this DID/SSI project, the following security considerations are critical:

#### W3C DID Specification Compliance
- **Mandatory Compliance**: All DID operations must conform to W3C DID Core v1.0 specification
- **Document Structure**: Verify that DID documents follow the correct JSON-LD format
- **Method Support**: Ensure multi-method DID resolution works as specified
- **Verification Method Format**: VM properties must match W3C requirements

#### Privacy and Data Protection
- **On-Chain Storage**: Consider privacy implications of storing identity data on-chain
- **GDPR Considerations**: Blockchain immutability conflicts with "right to be forgotten"
- **PII Minimization**: Store only necessary data on-chain, use hashes where possible
- **Controller Privacy**: Protect controller addresses and relationships

#### Gas Cost Optimization
- **Identity Operations**: Gas costs must be reasonable for real-world adoption
- **DID Creation**: Should be affordable for individual users
- **Updates**: Frequent operations (VM updates, service changes) need efficient implementation
- **Batch Operations**: Consider supporting batch updates to reduce per-operation costs

#### Multi-Method DID Security
- **Method Validation**: Ensure method bytes are properly validated and immutable
- **Cross-Method**: Prevent confusion attacks between different method namespaces
- **Method Collision**: Hash-based indexing must prevent collisions

#### Verification Method Security
- **Key Management**: Secure storage and validation of cryptographic keys
- **VM Types**: Support standard key types (EcdsaSecp256k1, Ed25519, etc.)
- **VM Updates**: Ensure proper authentication for VM additions/removals
- **VM Revocation**: Implement secure verification method deactivation

#### Controller Delegation Security
- **Authorization**: Verify controller permissions before state changes
- **Delegation Chain**: Prevent circular or malicious delegation patterns
- **Controller Updates**: Secure mechanism for controller changes
- **Attack Surfaces**: Protect against controller impersonation

#### Common Attack Vectors
- **Reentrancy**: Protect external calls and state changes
- **Front-running**: Consider MEV implications for DID operations
- **Signature Replay**: Prevent signature reuse across different contexts
- **DoS**: Protect against resource exhaustion attacks
- **Access Control**: Ensure only authorized parties can modify DIDs

### Security Review Process

When requesting security audits, use **@blockchain-code-assassin** (manual invocation only):

```
User: "@blockchain-code-assassin, please audit DidManager.sol for security issues"
```

The agent will perform:
- Reentrancy analysis
- Access control validation
- Gas optimization review
- W3C DID compliance check
- Common vulnerability scan

**Never auto-route to blockchain-code-assassin** - always wait for explicit user approval due to the depth and cost of analysis.

## File References

**For detailed information, check these files**:

| File | Purpose | What's Inside |
|------|---------|---------------|
| **PROJECT.md** | Project knowledge base | Architecture, DID concepts, design patterns, file organization |
| **foundry.toml** | Foundry configuration | Solidity version, optimizer, formatter settings |
| **docs/metrics/** | Performance tracking | Gas costs, coverage trends (academic quality) |
| **~/.claude/CLAUDE.md** | Global routing rules | Multi-AI orchestration, routing keywords, agent selection |
| **~/.claude/agents/** | Agent definitions | Individual agent capabilities and instructions |

---

**Last Updated**: 2026-03-05
**Purpose**: Claude Code project-specific context and routing overrides
**Architecture**: Simplified 2-file system (CLAUDE.md + PROJECT.md)
**Routing**: Inherits global rules from ~/.claude/CLAUDE.md with project-specific overrides
