# CLAUDE.md - SSIoBC-did

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Table of Contents

- [Quick Facts](#quick-facts)
- [Essential Commands](#essential-commands)
- [Project Knowledge Reference](#project-knowledge-reference)
- [Development Guidelines](#development-guidelines)
- [Security Guidelines](#security-guidelines)
- [File References](#file-references)

## Quick Facts

- **Project**: W3C-compliant fully on-chain DID management system
- **Innovation**: First complete on-chain DID document storage (vs event-based)
- **Language**: Solidity 0.8.33 (Foundry framework)
- **Coverage**: >90% required (enforced in CI/CD)
- **Architecture**: Dual-variant (Full W3C + Ethereum-Native) with shared DidAggregate (incl. isAuthorized) + VMHooks (9 hooks) + ServiceStorage + HashUtils (Template Method pattern)
- **Storage**: Hash-based lists with EnumerableSet (gas-optimized)
- **Standards**: W3C DID Core v1.0 compliant

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
1. **DidManager.sol** - Thin wrapper: createDid, createVm, getVm (inherits VMStorage + DidAggregate)
2. **storage/VMStorage.sol** - Verification methods storage (abstract, multi-type VMs)
3. **W3CResolver.sol** - W3C-compliant document resolution (extends W3CResolverBase)

**Ethereum-Native Variant** (single-key, Ethereum-only):
4. **DidManagerNative.sol** - Thin wrapper (inherits VMStorageNative + DidAggregate)
5. **storage/VMStorageNative.sol** - Native VM storage (abstract, 1-slot address-based VMs)
6. **W3CResolverNative.sol** - Resolution with field derivation (extends W3CResolverBase)

**Shared:**
7. **DidAggregate.sol** - All shared DID lifecycle logic (expiration, controllers, auth, isAuthorized, services, validation)
8. **storage/VMHooks.sol** - 9 abstract VM storage hook declarations (shared ancestor, avoids diamond)
9. **W3CResolverBase.sol** - Shared resolver logic (resolve, resolveService)
10. **storage/ServiceStorage.sol** - Service endpoints storage (abstract contract)
11. **HashUtils.sol** - Shared hash helper library (calculateIdHash, calculatePositionHash)

**Types** (src/types/): DidTypes.sol, VmTypes.sol, VmTypesNative.sol, ServiceTypes.sol, W3CTypes.sol
**Interfaces** (src/interfaces/): IDidManager (composite), IDidManagerFull, IDidManagerNative, IDidReadOps, IDidWriteOps, IDidAuth, IVMStorage, IVMStorageNative, IServiceStorage, IW3CResolver

### DID Structure

```
did:method0:method1:method2:id
```

- **Methods**: bytes32 with three 10-byte segments (default: "lzpf::main::")
- **ID**: Generated from `keccak256(methods, random, msg.sender, block.prevrandao)`
- **Hash**: `keccak256(methods, id)` for storage indexing

### Key Design Patterns

- **Hash-Based Storage**: O(1) operations via HashUtils library (shared by VMStorage + ServiceStorage)
- **EnumerableSet**: Efficient set operations for VMs and Services
- **Immutable Architecture**: No proxies, no upgrades
- **Custom Errors**: Gas optimization (all contracts use custom errors, no require strings)
- **Template Method + VMHooks**: DidAggregate calls abstract hooks; VMStorage variants implement them via shared VMHooks ancestor (no diamond)
- **Abstract Storage**: Modular VMStorage/VMStorageNative and ServiceStorage (in src/storage/)
- **Storage Caching**: Direct storage reads with early exit (e.g., _isControllerFor, _isExpired)
- **Resolution-time Derivation**: W3CResolverNative derives VM fields at query time (zero extra storage)
- **onlyDirectEOA Guard**: all authenticated writes require msg.sender == tx.origin (direct EOA calls; tx.origin never used as identity)
- **ERC-1271 signers**: `isAuthorizedOffChainWithSigner` verifies EOA *and* contract signatures via OZ `SignatureChecker` (read path only; ERC-6492 unsupported)

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

### Quality Thresholds

- **Coverage**: >90% minimum (enforced in CI/CD)
- **Gas Tracking**: Update `docs/metrics/gas-costs-*.md` for significant changes
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
- **security**: Slither static analysis with SARIF artifact upload
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

## File References

**For detailed information, check these files**:

| File | Purpose | What's Inside |
|------|---------|---------------|
| **PROJECT.md** | Project knowledge base | Architecture, DID concepts, design patterns, file organization |
| **foundry.toml** | Foundry configuration | Solidity version, optimizer, formatter settings |
| **docs/metrics/** | Performance tracking | Gas costs, coverage trends (academic quality) |

---

**Last Updated**: 2026-06-10
**Architecture**: Simplified 2-file system (CLAUDE.md + PROJECT.md)

# context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any Bash command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `ctx_fetch_and_index(url, source)` to fetch and index web pages
- `ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with Bash.
Instead use:
- `ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch — BLOCKED
WebFetch calls are denied entirely. The URL is extracted and you are told to use `ctx_fetch_and_index` instead.
Instead use:
- `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Bash (>20 lines output)
Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### Read (for analysis)
If you are reading a file to **Edit** it → Read is correct (Edit needs content in context).
If you are reading to **analyze, explore, or summarize** → use `ctx_execute_file(path, language, code)` instead. Only your printed summary enters context. The raw file content stays in the sandbox.

### Grep (large results)
Grep results can flood context. Use `ctx_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `ctx_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `ctx_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `ctx_execute(language, code)` | `ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `ctx_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically injected into their prompt. Bash-type subagents are upgraded to general-purpose so they have access to MCP tools. You do NOT need to manually instruct subagents about context-mode.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `ctx_search(source: "label")` later.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `ctx_stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `ctx_doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `ctx_upgrade` MCP tool, run the returned shell command, display as checklist |
