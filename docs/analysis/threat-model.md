# Threat Model

## Table of Contents

- [Architecture Security Properties](#architecture-security-properties)
- [DID ID Predictability](#did-id-predictability)
- [Front-Running Risk](#front-running-risk)
- [Controller Delegation Attacks](#controller-delegation-attacks)
- [Intermediary-Contract Impersonation (Confused Deputy)](#intermediary-contract-impersonation-confused-deputy)
- [Contract-Held Verification Methods](#contract-held-verification-methods)
- [Reactivation Rule](#reactivation-rule)
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
- **VM validation**: New VMs require the VM's own address to call `validateVm` (proves key ownership; since v1.8.0 that address may be a contract, see [Contract-Held Verification Methods](#contract-held-verification-methods))
- **Reactivation**: Both paths of `reactivateDid` need a live authentication key (see [Reactivation Rule](#reactivation-rule))

---

## DID ID Predictability

### Current Implementation

DID IDs are generated from:
```solidity
keccak256(abi.encodePacked(methods, random, msg.sender, block.prevrandao))
```

### Analysis

- **`msg.sender`**: Deterministic per sender, provides uniqueness across accounts (always the signing EOA, since `onlyDirectEOA` enforces `msg.sender == tx.origin`)
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

## Intermediary-Contract Impersonation (Confused Deputy)

### Pre-v1.4.0 Vulnerability

Before v1.4.0, on-chain authentication compared `tx.origin` against the VM's `ethereumAddress`. Because `tx.origin` is the transaction's originating EOA regardless of call depth, **any contract a user interacted with** (a phishing dApp, a malicious token, a compromised protocol) could call the DID contracts mid-transaction and pass authentication as that user — a classic confused-deputy / `tx.origin` phishing hole.

### v1.4.0 Mitigation

- **`msg.sender` authentication**: All identity checks now use `msg.sender` — `createDid` (ID entropy + initial VM binding), `reactivateDid`, and `_validateSenderAndTarget` (which feeds `expireVm`, `deactivateDid`, `updateController`, `updateService`, `createVm`).
- **`onlyDirectEOA` guard**: 7 of the 8 authenticated write entry points per variant require `msg.sender == tx.origin`, so the authenticated address is exactly the account that signed the transaction. `tx.origin` survives only inside this equality guard, never as identity. Before v1.8.0 all 8 carried the guard; `validateVm` no longer does (see [Contract-Held Verification Methods](#contract-held-verification-methods)).

### Limit of the Guard Under EIP-7702

**The guard does not prove "no intermediary contract is in the call chain."** That was the original
claim and it stopped being true when EIP-7702 went live with Pectra. A delegated EOA carries code,
so any call it makes still satisfies `msg.sender == tx.origin`. Verified in this repository against
the real cheatcode (`vm.signAndAttachDelegation`, `evm_version = 'osaka'`): after delegation the
account's `code.length` is 23, the `0xef0100 || address` indicator, and guarded writes from it
succeed. If a delegate executes arbitrary calls for arbitrary callers, a third-party contract can
reach a guarded entry point through it.

What the guard still guarantees is narrower, and it is the property the authorization model
actually needs: **the authenticated address is exactly the account that signed the transaction.**
Pre-v1.4.0 `tx.origin` authentication did not give that, which is what made every contract a user
touched into a deputy. Choosing a delegate that lets third parties act on your behalf is a decision
made at the wallet, and no on-chain guard here can override it.

Users who want the strong "no intermediary" property must not delegate to a permissive delegate.
This is documented rather than mitigated, because mitigating it on-chain would require inspecting
the delegate's code, which is neither reliable nor forward-compatible.

### Residual Trade-off

Smart-account/AA callers (multisigs, smart accounts, meta-tx forwarders, ERC-4337 bundlers) are **intentionally blocked on-chain for now** on the 7 guarded writes: such calls revert with `DirectEOACallRequired()`. The one exception is `validateVm`, where a contract may validate a VM bound to its own address. EIP-7702-delegated EOAs continue to work on write paths, subject to the limit above. Signature-based flows can use `isAuthorizedOffChain` (gasless, `ecrecover`-based) or `isAuthorizedOffChainWithSigner`, which additionally accepts **ERC-1271** contract signatures through OpenZeppelin `SignatureChecker`. That path is read-only (a `view` reached by `eth_call` or `staticcall`), so a malicious `isValidSignature` implementation cannot mutate state; a reverting one returns false rather than bubbling. ERC-6492 counterfactual wallets are out of scope: the signing account must already be deployed.

Two behavioural notes on `isAuthorizedOffChainWithSigner`. First, a 7702-delegated EOA whose
delegate does not implement `isValidSignature` would otherwise fail, because `SignatureChecker`
branches on `code.length` and staticcalls a function that does not exist; an ECDSA fallback covers
it. That grants nothing new, since under EIP-7702 the private key retains full control of the
account. Second, this view rejects a malleated high-`s` signature while the raw-`ecrecover`
`isAuthorizedOffChain` accepts it; prefer this view.

---

## Contract-Held Verification Methods

Since v1.8.0 a contract can hold an active verification method (VM) of a DID, for example an issuer contract that signs in the name of its DID. `validateVm` no longer carries `onlyDirectEOA`. Its only rule is that `msg.sender` is the VM's own `ethereumAddress`, so a contract validates a VM bound to itself, and nobody can validate a VM bound to another address. The other 7 writes stay direct-EOA, so a contract key can authorize through `isAuthorized` (for example in VClaim) but can never write a DID document. Full analysis, probes and findings: `docs/analysis/contract-vm-validation-design.md`.

### What a Contract Key Cannot Do

- It cannot act on a DID it does not control. The probes found no path from a validated contract VM to power over a foreign DID.
- It cannot perform a DID write: all 7 guarded writes revert `DirectEOACallRequired` for a contract caller. A property test and a unit test hold this for both variants.
- Nobody else can validate it. The rule is that `msg.sender` must equal the VM's `ethereumAddress` (`src/storage/VMStorage.sol` line 133, `src/storage/VMStorageNative.sol` line 114), so the DID owner or a controller, which are other addresses, cannot validate it either. Tested: a stranger, called directly or through an intermediary, and a user's own EOA going through an intermediary, all revert `InvalidSignature` (`test_RevertWhen_ValidateVm_CallerIsNotTheVmAddress`, `test_RevertWhen_ValidateVm_IntermediaryTriesUsersVm`). The owner and controller callers are not separately tested. Consent is the contract's own code.

### Warnings (design findings 1, 2, 6 and 11)

1. **The VM binds an address, not code (finding 1).** A constructor can validate a VM and self-destruct in the same transaction, and a later CREATE2 with the same salt can put other runtime code at the validated address. An upgradeable proxy changes what the key does when its admin upgrades it. A controller who names an address cannot rely on having read its code today. The remedy is the one for a leaked EOA key: expire the VM with `expireVm`.
2. **An open-call contract hands consent to anyone (findings 2 and 11).** A contract that executes arbitrary calls for arbitrary callers (a multicall, a router, a relayer without access control) can be validated by anyone who drives it, who also picks the expiration. A controller who is talked into naming such a contract as a key makes its DID, and every DID it controls, usable by anyone in VClaim and Trust. Name only contracts whose validation is behind access control and whose expiration is fixed in code (the reference issuer in `test/mocks/MockContractKeys.sol`). The expiration argument is a `uint256` that the contract truncates to 88 bits, so a value of `2**88` or more makes the `VmValidated` event untrue; it harms only the address's own VM.
3. **A DID whose only live `0x01` keys are contracts cannot write its own document (finding 6).** Every document write needs a direct-EOA authentication key. Keep at least one live EOA key with the `0x01` bit, or a controller that has one.

### EIP-7702 Consent Change (finding 3)

For a 7702 account the consent to validate moves from "the key signed a transaction" to "the delegate's code made the call". If the delegate executes calls for any caller, a relayer can validate the account's VM without the key's transaction. This was already the guard's limit for the 7 guarded writes (see [Limit of the Guard Under EIP-7702](#limit-of-the-guard-under-eip-7702)); `validateVm` now joins them. Do not delegate to a permissive delegate.

### Limits Found After Release (2026-11-18)

Three limits were found after v1.8.0 and verified on unchanged v1.8.0 source on both variants (evidence: `docs/assets/data/contract-vm-validation/probe-lifetime.t.sol.txt` and `probe-lifetime-results.txt`). None lets anyone act on a DID whose controller never named them. They limit how well a controller can take a naming back. The analysis is in `docs/analysis/contract-vm-validation-design.md`, section Limits Found After Release; a code change is proposed for v1.9.0.

- **L1, the validator picks the lifetime without an upper bound.** `validateVm` stores any value up to the largest 88-bit number. For a contract that makes arbitrary calls, a stranger chooses it. After the owner's own key has passed its 365 days, the owner can no longer expire that contract key or create a key, and the contract key stays authorized until the DID lapses. Another live key of the DID, or a live key of a controller DID, can still expire it.
- **L2, a pending key can be validated on a deactivated DID.** `validateVm` does not read the state of the DID. A key that was named but never validated can validate itself after the DID was deactivated and after every other key expired, and then reactivate the DID. The sentence "a DID with no controller whose authentication keys have all expired while it was deactivated cannot be reactivated" holds only when no key is still pending. On a DID that lapsed by time, a pending key can validate but is not authorized and cannot reactivate it.
- **L3, a pending key cannot be withdrawn.** `expireVm` on a key that was never validated reverts `VmAlreadyExpired`, even while the owner's key is live, and the named address can still validate later. A naming is a standing offer with no cancel.

Plain warnings for DID owners:

1. Renew your own authentication key before it expires. An expired key cannot revoke anything.
2. Do not leave a pending key behind. It cannot be withdrawn, and the named address can validate it at any time.
3. Before you deactivate a DID for good, know that a pending authentication key can bring it back. Expire the other keys and make sure no key is pending, or keep a controller.
4. Never name a contract that forwards arbitrary calls. A stranger can validate it and choose how long its key lives.

### Test-Net Limit

The invariant `invariant_NoGuardedWriteSucceedsFromAContract` covers 6 of the 7 guarded writes: the handler never deactivates a DID, so `reactivateDid` is not reached from a contract. The unit test `test_RevertWhen_ContractKeyCallsAnyGuardedWrite` covers all 7 with the exact revert, on both variants. Mutation evidence: `docs/assets/data/contract-vm-validation/mutation-proof.txt`.

---

## Reactivation Rule

### What Was Possible in v1.7.0 and Earlier

On the self path (`senderId == targetId`) `reactivateDid` checked only that the caller's address was in a VM with the `0x01` bit (`_isVmOwner`). It did not check that the VM was validated, unexpired, or that the controller rule held. Verified by `probe-reactivation` (`docs/assets/data/contract-vm-validation/probe-reactivation.t.sol.txt`), both variants:

| Case | v1.7.0 and earlier |
|---|---|
| a key that was validated and then expired reactivates a deactivated DID | succeeds |
| a key that was named but never validated reactivates | succeeds |
| a controller deactivates the DID; the DID's own key reactivates | succeeds |
| no controller, DID deactivated, key lifetime passed; the owner reactivates | succeeds, owner still not authorized |

### The v1.8.0 Rule

Both paths need a live authentication key (`_isAuthenticated`: validated, unexpired, `0x01`). An expired, pending or missing key reverts `VmAlreadyExpired`; a live key without the `0x01` bit reverts `NotAuthenticatedAsSenderId`. The controller rule applies on the controller path only (`NotAControllerForTargetId`).

### Accepted Residuals and Costs

- **A controller's deactivation is not final while the DID has a live key of its own (owner decision D5).** The DID's own live authentication key can reactivate it. A controller who wants the deactivation to be final must first expire those keys with `expireVm`, then deactivate.
- **A parked DID can be lost (owner decision D6).** A DID with no controller that stays deactivated until all its authentication keys have expired cannot come back, as an active DID is equally stuck once its last authentication key expires. Owners who park a DID by deactivating it should keep a controller, which can reactivate it.

### Deployed Contracts

The v1.7.0 contracts on Sepolia are immutable and keep the old behaviour. The cases in the table above remain possible there.

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
| List limits (255 VMs resolve, 256th service wrap) | MEDIUM, fixed in v1.7.0 | Before v1.7.0 both resolvers panicked (0x11) on a DID holding the maximum 255 VMs, so the DID could not be resolved at all, and a 256th service wrapped its `uint8` position to 0, hiding the entry and corrupting the reported list length. Both resolvers now loop with a 0-based counter and `ServiceStorage` reverts with `TooManyServices()` past 255 services. Resolve at 255 VMs costs about 25.9M gas (Full) and 19.0M gas (Native), under the 50M default `eth_call` cap |

### Position Overflow Protection

The `TooManyVerificationMethods` error prevents creating more than 255 VMs per DID (uint8 position overflow guard added in v1.2.0).

The same guard now covers services: `TooManyServices` prevents a 256th service per DID (added in v1.7.0). Positions are `uint8` in the ABI (`getServiceListLength`, `getService`), so the cap keeps the ABI instead of widening the type. Existing services on a full list can still be updated or deleted.

---

## Mitigations Summary

| Threat | Severity | Mitigation |
|--------|----------|------------|
| DID ID predictability | LOW | Adequate entropy from keccak256 inputs |
| Front-running | LOW | Authentication required for all mutations |
| Confused deputy (intermediary-contract impersonation) | HIGH (pre-v1.4.0, fixed) | `msg.sender` auth + `onlyDirectEOA` guard (v1.4.0) |
| Contract key that executes arbitrary calls (v1.8.0) | MEDIUM | Name only contracts with access-controlled validation and a fixed expiration; revoke with `expireVm` |
| Reactivation by a stale or unvalidated key (pre-v1.8.0) | MEDIUM (fixed) | Both paths need a live `0x01` key (v1.8.0); v1.7.0 deployments keep the old behaviour |
| Malicious controller | MEDIUM | Trust model, max 5 controllers |
| Privacy exposure | MEDIUM | Don't store PII, use off-chain for sensitive data |
| Resolver manipulation | HIGH (if exploited) | Verify deployment addresses, bytecode hashes |
| VM spam | LOW | Gas costs, uint8 position limit |
| Post-deployment bugs | MEDIUM | Redeploy strategy, thorough pre-deployment testing |
