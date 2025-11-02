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
- [File References](#file-references)

## Quick Facts

- **Project**: W3C-compliant fully on-chain DID management system
- **Innovation**: First complete on-chain DID document storage (vs event-based)
- **Language**: Solidity 0.8.24 (Foundry framework)
- **Coverage**: >90% required (enforced in CI/CD)
- **Architecture**: 4 contracts (DidManager, VMStorage, ServiceStorage, W3CResolver)
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

**Note**: Global routing rules are defined in `/Users/miguel_lzpf/.claude/CLAUDE.md`. This section contains SSIoBC-specific routing and Claude's role as orchestrator.

### Claude's Role (Orchestrator)

You (Claude Code) are the **orchestrator** responsible for:

1. **Analyzing user requests** and determining task complexity
2. **Routing tasks** to specialized AIs when appropriate:
   - **Gemini** → Research, documentation lookup, standards investigation
   - **GitHub Copilot** → Well-defined, time-bounded, actionable tasks
3. **Handling complex reasoning** directly (architecture, debugging, design decisions)
4. **Synthesizing results** from delegated tasks
5. **Ensuring quality** across all outputs

### Routing Decision Tree

**MANDATORY PRE-PROCESSING CHECK** - Before processing ANY user request:

```
User Request Received
    │
    ├─ Contains "research|search|find|look up|documentation|docs|spec|latest"?
    │  └─ YES → STOP → Route to Gemini (@agent-truth-seeker-gemini)
    │          Use GEMINI.md context
    │
    ├─ Contains "format|lint|fix style|clean code|prettier"?
    │  └─ YES → STOP → Route to Copilot (@agent-code-worker)
    │          Use AGENTS.md context
    │
    ├─ Contains "commit|push|PR|pull request|branch|merge|rebase"?
    │  └─ YES → STOP → Route to Git Agent (@agent-git-maestro)
    │          Ensure PGP signing
    │
    ├─ Contains "review contract|audit|security|gas optim|vulnerabil"?
    │  └─ YES → STOP → Route to Blockchain Specialist (@agent-blockchain-code-assassin)
    │          Security-critical, domain expertise required
    │
    ├─ Well-defined task, clear start/end, minimal context needed?
    │  └─ YES → Consider routing to Copilot (use judgment)
    │
    └─ Complex reasoning, architecture, debugging, novel problems?
       └─ Handle directly with Claude (you)
```

### Keyword-to-Agent Mapping

| Trigger Keywords | Route To | Agent | Context File | Token Savings |
|-----------------|----------|-------|--------------|---------------|
| research, search, find, documentation, docs, spec, latest, standards | Gemini | @agent-truth-seeker-gemini | GEMINI.md | 100% |
| format, lint, fix style, clean code, prettier, organize imports | Copilot | @agent-code-worker | AGENTS.md | 90-100% |
| commit, push, PR, pull request, branch, merge, rebase, git | Git Agent | @agent-git-maestro | N/A | Standard |
| review contract, audit, security, gas optim, vulnerabil, reentrancy | Blockchain | @agent-blockchain-code-assassin | N/A | Domain-critical |

### Project-Specific Routing Enhancements

#### Enhanced Security Focus (Blockchain Project)

**ALL smart contract reviews** → Always route to `@agent-blockchain-code-assassin`:
- Security audits are CRITICAL for smart contracts
- Gas optimization requires domain expertise
- Reentrancy, overflow, and access control vulnerabilities
- W3C compliance verification for DID implementations

**Examples**:
```
✓ "Review DidManager.sol"
  → Routes to blockchain-code-assassin (security-critical)

✓ "Check for gas optimizations in VMStorage"
  → Routes to blockchain-code-assassin (domain expertise)

✓ "Analyze the controller system for vulnerabilities"
  → Routes to blockchain-code-assassin (security focus)
```

#### Research Routing for Standards

**W3C DID and blockchain standards research** → Always route to Gemini:
- W3C DID Core specification updates
- EIP/ERC standard documentation
- Solidity best practices and patterns
- Blockchain identity standards

**Examples**:
```
✓ "Research W3C DID resolution specification"
  → Routes to Gemini (standard documentation)

✓ "Find latest ERC-1056 implementation patterns"
  → Routes to Gemini (research task)

✓ "Look up Foundry fuzzing best practices"
  → Routes to Gemini (documentation lookup)
```

### Routing Verification Self-Check

Before responding to any user request, verify:

1. ✓ Did I scan the user's request for routing keywords?
2. ✓ If routing keywords found, did I invoke the appropriate agent?
3. ✓ Did I wait for agent results before responding?
4. ✓ Am I processing directly only when NO routing keywords present?

**If you answered NO to any question above → YOU ARE VIOLATING ROUTING RULES**

### When to Handle Directly (Claude)

Handle these tasks directly without routing:

- **Architecture Design**: System design, pattern selection, trade-off analysis
- **Complex Debugging**: Root cause analysis, multi-layer issues
- **Strategic Decisions**: Technology choices, design patterns
- **Novel Problems**: No established patterns, requires reasoning
- **Cross-System Integration**: Multiple contracts, complex interactions
- **Business Logic**: DID lifecycle, controller delegation, complex state management

## Project Knowledge Reference

**Detailed project information is in PROJECT.md** - reference it for:

- Complete smart contract architecture (4-contract system)
- DID structure and concepts (methods, ID, hash generation)
- Verification methods (VMs) and controller system
- Design patterns (hash-based storage, EnumerableSet, etc.)
- Innovation claims and comparison with existing solutions
- File organization and artifact management

**Quick Summary**:

### Four-Contract System

1. **DidManager.sol** - Core DID lifecycle (inherits VMStorage + ServiceStorage)
2. **VMStorage.sol** - Verification methods storage (abstract contract)
3. **ServiceStorage.sol** - Service endpoints storage (abstract contract)
4. **W3CResolver.sol** - W3C-compliant document resolution

### DID Structure

```
did:method0:method1:method2:id
```

- **Methods**: bytes32 with three 10-byte segments (default: "lzpf::main::")
- **ID**: Generated from `keccak256(methods, random, tx.origin, block.prevrandao)`
- **Hash**: `keccak256(methods, id)` for storage indexing

### Key Design Patterns

- **Hash-Based Storage**: O(1) operations vs O(n) arrays
- **EnumerableSet**: Efficient set operations for VMs and Services
- **Immutable Architecture**: No proxies, no upgrades
- **Custom Errors**: Gas optimization (vs require strings)
- **Abstract Storage**: Modular VMStorage and ServiceStorage

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

- **Solidity**: 0.8.24 (fixed version)
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

- Hash-based storage instead of arrays where possible
- EnumerableSet for efficient set operations
- Storage caching (single SLOAD vs multiple)
- Unchecked arithmetic when safe
- Custom errors over require strings

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

GitHub Actions (`.github/workflows/ai-quality-check.yml`):
- Automatic coverage reporting
- Gas cost analysis
- Security scan summary
- PR comments with quality metrics

## File References

**For detailed information, check these files**:

| File | Purpose | What's Inside |
|------|---------|---------------|
| **PROJECT.md** | Project knowledge base | Architecture, DID concepts, design patterns, file organization |
| **AGENTS.md** | Copilot instructions | Code standards, testing patterns, gas optimization, security |
| **GEMINI.md** | Research context | Research mandate, citation requirements, focus areas |
| **foundry.toml** | Foundry configuration | Solidity version, optimizer, formatter settings |
| **docs/metrics/** | Performance tracking | Gas costs, coverage trends (academic quality) |

---

**Last Updated**: 2025-01-02
**Purpose**: Claude Code orchestration and routing instructions
**Role**: Orchestrator (delegates to Gemini/Copilot, handles complex reasoning)
**Context**: Moderate detail with references to detailed files
