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

### ERC-1056 Gas Comparison

Measured against the ERC-1056 reference registry (`uport-project/ethr-did-registry` 1.3.0, tag commit `22b55e5`). SSIoBC-did v1.7.0 candidate, measured on the pull request that added this comparison (#44), on 2026-10-24, with Foundry 1.8.1, solc 0.8.36, EVM osaka, optimizer 200 runs. Reproduce with:

```bash
FOUNDRY_PROFILE=ci_thorough forge test --match-path test/performance/EthrDidComparison.performance.t.sol -vv
```

**Method.** Each operation is one top-level external call from cold state (`vm.cool` on the target before the call), read with `vm.lastFrameGas()`, which returns the same figure as `vm.snapshotGasLastCall`: the gas of the callee frame. It excludes the 21,000 intrinsic transaction gas and the calldata gas, and includes every cold storage and account access inside the callee. A transaction costs these figures plus 21,000 plus calldata gas (4 per zero byte, 16 per non-zero byte); the test logs the calldata gas of each call. Both sides receive the same payload: one 64-byte public key string (as `publicKeyMultibase` and as the `setAttribute` value) and one 23-byte service endpoint string. "N existing" is the number of entries the document already holds before the measured call: verification methods for SSIoBC-did (a DID always holds `vm-0`, so the smallest document has 1) and attributes for ERC-1056 (an identity can hold 0). Each ERC-1056 write runs in its own block, as on a real chain. Figures were checked equal with and without `--isolate`. Ceilings in the test file sit 5% above these values. SSIoBC Full stores the key in a VM with no Ethereum address; SSIoBC Native stores a `publicKeyMultibase` only for a `keyAgreement` VM and always with an address, so its row is the closest Native shape.

| Operation (execution gas) | SSIoBC Full | SSIoBC Native | ERC-1056 | Resolution model |
|---|---:|---:|---:|---|
| Create identity | 278,089 | 211,700 | 0 (implicit, no transaction) | ours: a stored record; ERC-1056: every address already owns itself |
| Add key by public key string, 1 existing | 321,739 | 253,852 | 34,861 (`setAttribute`) | stored in contract storage vs emitted as an event |
| Add key by public key string, 3 existing | 321,739 | 253,852 | 34,861 | same |
| Add key by public key string, 5 existing | 321,739 | 253,852 | 34,861 | same |
| Add key by public key string, empty ERC-1056 document | not applicable | not applicable | 51,961 | first write of the per-identity `changed` pointer |
| Add key by Ethereum address | 253,995 | 185,593 | 72,001 (`addDelegate`, closest analogue) | stored vs emitted as an event |
| Validate key (proof of control by that address) | 35,357 | 33,354 | no equivalent | on-chain flag vs none |
| Change controller / owner | 66,313 | 66,336 | 68,609 (`changeOwner`) | storage write vs storage write plus event |
| Add service endpoint (ERC-1056: 1, 3 or 5 existing, then empty) | 203,454 | 203,367 | 33,877, 33,877, 33,877, then 50,977 | stored vs emitted as an event |
| Resolve document, 1 VM (view) | 214,274 | 192,069 | no on-chain equivalent | ours: one `eth_call`; ERC-1056: off-chain replay of the identity's log chain |
| Resolve document, 3 VMs (view) | 383,166 | 316,444 | no on-chain equivalent | same |
| Resolve document, 5 VMs (view) | 552,204 | 440,945 | no on-chain equivalent | same |
| On-chain authorization check (view) | 17,578 (`isAuthorized`) | 17,550 (`isAuthorized`) | 2,649 (`identityOwner`), 2,992 (`validDelegate`) | a contract can call either in one call |

The `resolve` rows are `eth_call` figures: an off-chain caller pays nothing for them. The service row for SSIoBC-did was measured on a DID with only `vm-0` and no service; the SSIoBC-did add-key rows do not change with the document size (321,739 and 253,852 at 1, 3 and 5 existing VMs), and the ERC-1056 rows do not either once the first write is past.

**What the extra gas buys.** A write here stores the document state in contract storage, so a contract can read it in one call (`resolve`, `isAuthorized`) and an off-chain client needs no log index to know the current document. ERC-1056 stores one pointer per identity and puts the content in events; the content is only readable by replaying them. Add-key and add-service cost about 4 to 9 times the ERC-1056 figure (321,739 against 34,861 for a 64-byte key on Full, 203,454 against 33,877 for a service), and that ratio is the price of the stored form.

**Where ERC-1056 is cheaper.** Creating an identity is free because there is nothing to create: the owner is the address itself until `changeOwner` is called. Every write that only emits an event, `setAttribute` and `addDelegate`, is far below a stored write. The authorization views cost about 6 times less (2,649 against 17,578). `updateController` and `changeOwner` are within 4% of each other, so for that operation there is no gap.

**Caveat.** ERC-1056 resolution is off-chain: a client reads the `changed` pointer and walks the chain of `DIDAttributeChanged`, `DIDDelegateChanged` and `DIDOwnerChanged` events, one log query per link, and it has to run or trust an indexer for that. That cost is not zero, it moves to the client. Our `resolve` is an `eth_call` and costs an off-chain caller nothing, but a contract that calls it pays the figures above, and they grow with the number of VMs (about 84,000 per extra VM on Full, 62,000 on Native). Neither design is free at scale: for ERC-1056 the cost sits in indexing, for ours in the storage paid at write time and in on-chain resolution. The 1 to 5 VM range measured here says nothing about behaviour near the 255-VM limit.

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
- **Solidity version**: 0.8.36
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
- Both share DidAggregate (aggregate root), VMHooks (shared ancestor), ServiceStorage, and HashUtils
- Native variant achieves ~13% bytecode size reduction

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
