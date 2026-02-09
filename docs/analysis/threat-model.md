# Threat Model

## Table of Contents

- [Architecture Security Properties](#architecture-security-properties)
- [DID ID Predictability](#did-id-predictability)
- [Front-Running Risk](#front-running-risk)
- [Controller Delegation Attacks](#controller-delegation-attacks)
- [Privacy Considerations](#privacy-considerations)
- [Deployment-Time Risks](#deployment-time-risks)
- [Denial of Service](#denial-of-service)
- [Mitigations Summary](#mitigations-summary)

---

## Architecture Security Properties

### Immutable Architecture

The system uses **no proxies or upgradability patterns**, which provides:

**Benefits:**
- Reduced attack surface (no proxy admin key compromise)
- No storage collision risks from delegatecall
- Deterministic behavior (code cannot change post-deployment)
- Simpler security auditing

**Trade-offs:**
- Cannot fix vulnerabilities post-deployment (must redeploy)
- Cannot add features without new contract deployment
- State migration requires manual DID recreation

### Access Control Model

- **Authentication**: VM owner must have `relationships & 0x01` flag set
- **Controller delegation**: Up to 5 controllers per DID, checked via `_isControllerFor`
- **VM validation**: New VMs require address owner to call `validateVm` (proves key ownership)

---

## DID ID Predictability

### Current Implementation

DID IDs are generated from:
```solidity
keccak256(abi.encodePacked(methods, random, tx.origin, block.prevrandao))
```

### Analysis

- **`tx.origin`**: Deterministic per sender, provides uniqueness across accounts
- **`random`**: User-provided randomness, adds entropy if chosen well
- **`block.prevrandao`**: Pseudo-random from beacon chain, known to validators ~1 slot ahead

### Risk Level: LOW

DID ID predictability is not a critical security concern because:
1. DID creation is not a competitive operation (no front-running incentive for IDs)
2. The ID itself doesn't grant permissions (authentication is address-based)
3. Collision resistance comes from keccak256 over 128+ bytes of input

### Recommendation

For applications requiring unpredictable DID IDs, use a strong random value in the `random` parameter (e.g., client-side `crypto.getRandomValues`).

---

## Front-Running Risk

### Scenarios

| Operation | Front-Running Risk | Impact |
|-----------|-------------------|--------|
| `createDid` | LOW | Attacker could claim same ID first (unlikely due to entropy) |
| `createVm` | LOW | Attacker would need to be authenticated for the DID |
| `updateController` | MEDIUM | Controller changes could be front-run by existing controller |
| `deactivateDid` | LOW | Only authorized parties can deactivate |
| `validateVm` | LOW | Only the VM's ethereum address can validate |

### MEV Considerations

- DID operations are not financially incentivized for MEV extraction
- No token transfers or value extraction possible through front-running
- Controller update ordering could matter in adversarial multi-controller scenarios

### Mitigation

The `_validateSenderAndTarget` pattern ensures only authenticated senders can modify DIDs, making front-running ineffective for unauthorized parties.

---

## Controller Delegation Attacks

### Attack Surface

Controllers can perform operations on behalf of a DID. Potential attack vectors:

### 1. Malicious Controller Assignment
- **Vector**: DID owner assigns a controller that later acts maliciously
- **Impact**: Controller can add VMs, update services, assign more controllers
- **Mitigation**: DID owner should only assign trusted controller DIDs
- **Limitation**: Maximum 5 controllers (CONTROLLERS_MAX_LENGTH)

### 2. Controller Circular Delegation
- **Vector**: DID A makes DID B a controller, DID B makes DID A a controller
- **Impact**: No direct vulnerability (operations still require valid authentication)
- **Analysis**: Circular references don't create privilege escalation

### 3. Stale Controller Access
- **Vector**: Controller DID expires or is deactivated but still listed
- **Impact**: Controller operations will fail authentication (expired DIDs can't authenticate)
- **Mitigation**: Built-in - `_isControllerFor` checks controller DID's expiration

### 4. Controller Removal Race
- **Vector**: Two controllers race to remove each other
- **Impact**: Transaction ordering determines outcome
- **Mitigation**: This is expected behavior in multi-party governance

---

## Privacy Considerations

### On-Chain Data Exposure

All DID document data is stored on-chain and publicly readable:

| Data | Visibility | Privacy Concern |
|------|-----------|-----------------|
| DID ID | Public | Links identity to address |
| VM addresses | Public | Ethereum addresses exposed |
| VM types | Public | Key type information |
| Services | Public | Endpoint URLs visible |
| Controllers | Public | Delegation relationships visible |
| Transaction history | Public | All DID operations traceable |

### GDPR Implications

- **Right to be forgotten**: Blockchain immutability conflicts with GDPR Article 17
- **Data minimization**: System stores only DID-related data (no PII by default)
- **Deactivation**: DIDs can be deactivated but data remains on-chain
- **Pseudonymity**: DID IDs are pseudonymous (not directly linked to real identity)

### Recommendations

1. **Do not store PII** in service endpoints or VM metadata
2. **Use off-chain storage** for privacy-sensitive attributes (with on-chain hash anchors)
3. **Consider privacy-preserving DID methods** for sensitive use cases
4. **Document GDPR compliance** position for deployments in EU jurisdictions

---

## Deployment-Time Risks

### Resolver-DidManager Binding

The W3CResolver is constructed with a reference to the DidManager:
```solidity
constructor(IDidManager didManager)
```

**Risk**: If the resolver is pointed to a malicious DidManager contract, it could return fabricated DID documents.

**Mitigation:**
1. Deploy DidManager first, verify its bytecode
2. Deploy resolver with the verified DidManager address
3. Verify resolver's `_didManager` storage slot matches expected address

### Deployment Order

Correct deployment order:
1. Deploy `DidManager` (or `DidManagerNative`)
2. Verify deployed bytecode hash
3. Deploy `W3CResolver` (or `W3CResolverNative`) with DidManager address
4. Verify resolver references correct DidManager

### Key Management

- Deployer private key must be secured
- Consider using hardware wallet for mainnet deployments
- Deployer has no special privileges after deployment (immutable architecture)

---

## Denial of Service

### Potential DoS Vectors

| Vector | Risk | Mitigation |
|--------|------|------------|
| VM spam (create many VMs) | LOW | Gas cost deters spam, uint8 position limits to 255 |
| Service spam | LOW | Gas cost deters spam, storage costs per service |
| Controller slot exhaustion | LOW | Maximum 5 controllers per DID |
| Large key material | LOW | Storage cost proportional to size |
| Resolver gas limit | MEDIUM | Complex DIDs with many VMs may approach block gas limit |

### Position Overflow Protection

The `TooManyVerificationMethods` error prevents creating more than 255 VMs per DID (uint8 position overflow guard added in v1.2.0).

---

## Mitigations Summary

| Threat | Severity | Mitigation |
|--------|----------|------------|
| DID ID predictability | LOW | Adequate entropy from keccak256 inputs |
| Front-running | LOW | Authentication required for all mutations |
| Malicious controller | MEDIUM | Trust model, max 5 controllers |
| Privacy exposure | MEDIUM | Don't store PII, use off-chain for sensitive data |
| Resolver manipulation | HIGH (if exploited) | Verify deployment addresses, bytecode hashes |
| VM spam | LOW | Gas costs, uint8 position limit |
| Post-deployment bugs | MEDIUM | Redeploy strategy, thorough pre-deployment testing |
