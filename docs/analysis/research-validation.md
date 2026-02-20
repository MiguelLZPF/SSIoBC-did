# Research Validation

## Table of Contents

- [W3C DID Core v1.0 Compliance](#w3c-did-core-v10-compliance)
- [Comparison Methodology](#comparison-methodology)
- [Gas Cost Measurement](#gas-cost-measurement)
- [Test Coverage as Validation](#test-coverage-as-validation)
- [Innovation Claims](#innovation-claims)

---

## W3C DID Core v1.0 Compliance

### Compliance Checklist

Based on [W3C DID Core v1.0](https://www.w3.org/TR/did-core/) specification:

| Requirement | Status | Implementation |
|------------|--------|---------------|
| DID Syntax (`did:method:id`) | Compliant | `did:method0:method1:method2:hexId` with 3-segment methods |
| DID Document structure | Compliant | `W3CDidDocument` struct matches spec |
| `@context` field | Compliant | `["https://www.w3.org/ns/did/v1"]` |
| `id` field (DID subject) | Compliant | Formatted as `did:method:hexId` string |
| `controller` field | Compliant | Array of DID strings (up to 5 controllers) |
| `verificationMethod` array | Compliant | Full VM properties including type, key material |
| `authentication` relationship | Compliant | Bitmask 0x01, VM reference strings |
| `assertionMethod` relationship | Compliant | Bitmask 0x02, VM reference strings |
| `keyAgreement` relationship | Compliant | Bitmask 0x04, VM reference strings |
| `capabilityInvocation` relationship | Compliant | Bitmask 0x08, VM reference strings |
| `capabilityDelegation` relationship | Compliant | Bitmask 0x10, VM reference strings |
| `service` endpoints | Compliant | Multiple types and endpoints via packed bytes |
| DID Resolution | Compliant | `resolve()` returns full W3C document |
| DID URL dereferencing | Partial | Fragment support for VM/service resolution |
| Deactivation | Compliant | `deactivateDid()` + `reactivateDid()` |

### Key Design Decisions

1. **On-chain storage vs event-based**: Full documents stored on-chain for direct resolution
2. **Bitmask relationships**: Gas-efficient encoding of 5 W3C relationship types in 1 byte
3. **Packed string encoding**: Services use `\x00` delimiter for multi-value type/endpoint fields
4. **Expiration in milliseconds**: W3C documents return millisecond timestamps (seconds * 1000)

---

## Comparison Methodology

### Compared Solutions

| Solution | Storage Model | Resolution | Key Types |
|----------|--------------|------------|-----------|
| **SSIoBC-DID (this)** | Full on-chain | Direct query | Multi-type + Native |
| ERC-1056 (uPort) | Event-based | Log reconstruction | secp256k1 only |
| EBSI DID | Off-chain + anchor | External resolver | Multiple |
| LACChain DID | Event-based | Log reconstruction | Multiple |
| ONCHAINID (ERC-734/735) | On-chain claims | Direct query | Limited |

### Comparison Criteria

1. **Storage completeness**: Does it store the full DID document on-chain?
2. **Resolution complexity**: Can a document be resolved with a single contract call?
3. **Gas efficiency**: What are the costs for common operations?
4. **W3C compliance**: Does it support all W3C DID Core relationships?
5. **Key flexibility**: Does it support multiple verification method types?

### Innovation: Full On-Chain Storage

Unlike event-based approaches (ERC-1056, LACChain) that require off-chain indexers to reconstruct DID documents from event logs, SSIoBC-DID stores complete documents on-chain. This enables:

- Direct resolution via a single `resolve()` call
- No dependency on external indexing infrastructure
- Guaranteed consistency (no indexer lag or missing events)
- Composability with other on-chain contracts

---

## Gas Cost Measurement

### Methodology

Gas costs are measured using Foundry's built-in gas reporting:

```bash
forge test --gas-report
```

### Measurement Conditions

- **EVM version**: Osaka (as configured in foundry.toml)
- **Optimizer**: Enabled, 200 runs
- **Solidity version**: 0.8.33
- **Network**: Local Anvil node (deterministic gas pricing)

### Reproducibility

Gas measurements are deterministic when:
1. Same Solidity compiler version is used
2. Same optimizer settings are applied
3. Same test inputs are provided (via Fixtures constants)
4. Same EVM version is targeted

### Key Metrics (v1.2.0)

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| DID Creation | ~250K | Includes default VM creation |
| VM Addition | ~150K | Varies by key material |
| VM Validation | ~50K | Signature verification |
| Service Update | ~80K | Dynamic bytes storage |
| DID Resolution | ~350K | Full W3C document assembly |
| Controller Update | ~60K | Storage write + auth check |

See `docs/metrics/gas-consumption-history.md` for version-by-version tracking.

---

## Test Coverage as Validation

### Coverage Requirements

- **Minimum threshold**: 90% (enforced in CI/CD)
- **Current coverage**: >90% across all source contracts
- **VMStorageNative**: 100% coverage (all metrics)

### Test Categories

| Category | Count | Purpose |
|----------|-------|---------|
| Unit tests | 258 | Individual function behavior |
| Fuzz tests | 21 | Property-based edge cases |
| Invariant tests | 15 | System-wide properties |
| Integration tests | 9 | Cross-contract workflows |
| Performance tests | 8 | Gas benchmarking |
| Stress tests | 6 | Performance under load |

### Coverage as Evidence

High test coverage validates:
1. **Correctness**: All code paths execute as designed
2. **Edge cases**: Boundary conditions are handled
3. **Error paths**: Custom errors fire correctly
4. **Integration**: Cross-contract interactions work
5. **Properties**: Invariants hold under random inputs

---

## Innovation Claims

### Claim 1: First Fully On-Chain DID Document Storage

**Evidence:**
- All existing Ethereum DID methods (ERC-1056, EBSI, LACChain) use event-based reconstruction
- SSIoBC-DID stores complete DID documents directly in contract storage
- Resolution is a single view call, not event log processing

### Claim 2: Dual-Variant Architecture

**Evidence:**
- Full W3C variant supports arbitrary key types and multi-slot VMs
- Ethereum-Native variant packs each VM into a single 32-byte slot
- Both share DidManagerBase, ServiceStorage, and HashUtils
- Native variant achieves ~19.4% bytecode size reduction

### Claim 3: Gas-Efficient On-Chain Storage

**Evidence:**
- Hash-based storage with EnumerableSet for O(1) operations
- Storage packing: Native VMs in 1 slot (address + relationships + expiration)
- ServiceStorage: 96% storage reduction via dynamic bytes (v1.0.1)
- Custom errors: ~50 bytes bytecode savings per error site
- Optimizer tuned for deployment size (200 runs)

### Claim 4: W3C DID Core Compliance

**Evidence:**
- All 5 W3C verification relationships supported
- DID document structure matches specification
- Service endpoints with multiple types/endpoints
- Controller delegation system
- Deactivation/reactivation lifecycle
