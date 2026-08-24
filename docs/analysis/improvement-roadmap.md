# SSIoBC-did — Community & Improvement Roadmap

> A prioritized catalogue of 24 concrete ways to strengthen the project technically and make it
> genuinely community-friendly / adoptable. Each idea states **What**, **Why it matters**,
> **How to implement** (concrete, repo-aware), **Strengths**, **Weaknesses/Risks**, and an
> **Effort × Impact** rating.
>
> Compiled 2026-06 from a source-level audit of `src/`, `script/`, `test/` plus four research
> dossiers in `.temp/research/` (`aa-did-landscape.md`, `did-ssi-standards.md`,
> `ssi-tooling-interop.md`, `oss-community-best-practices.md`). Citations live in those files.

## Table of Contents

- [How to Read This](#how-to-read-this)
- [Current State (audit baseline)](#current-state-audit-baseline)
- [Implementation Status](#implementation-status)
- [Theme A — Account Abstraction & Smart-Account Identity](#theme-a--account-abstraction--smart-account-identity)
  - [1. ERC-1271 / ERC-6492 controller signatures](#1-erc-1271--erc-6492-controller-signatures-foundational)
  - [2. ERC-7579 "DID Validator" module (flagship thesis)](#2-erc-7579-did-validator-module-flagship-thesis)
  - [3. EIP-7702 controller path + remove tx.origin from auth](#3-eip-7702-controller-path--remove-txorigin-from-auth)
  - [4. ERC-6551 token-bound-account DID subjects](#4-erc-6551-token-bound-account-did-subjects-research-track)
- [Theme B — Standards Alignment & Interoperability](#theme-b--standards-alignment--interoperability)
  - [5. Register the DID method in the W3C registry](#5-register-the-did-method-in-the-w3c-registry)
  - [6. DIF Universal Resolver driver](#6-dif-universal-resolver-driver)
  - [7. did-resolver-compatible JS resolver](#7-did-resolver-compatible-js-resolver-unlocks-veramo)
  - [8. Configurable @context + DID 1.1 / VC 2.0](#8-configurable-context--did-11--vc-20)
  - [9. EIP-712 typed data for signatures](#9-eip-712-typed-data-for-signatures)
  - [10. CAIP-10 + did:pkh import + did:ethr interop](#10-caip-10--didpkh-import--didethr-interop)
  - [11. EAS / Verax attestation bridge](#11-eas--verax-attestation-bridge)
  - [12. ethr-did benchmark + migration adapter](#12-ethr-did-benchmark--migration-adapter)
- [Theme C — Off-chain Tooling & Developer Experience](#theme-c--off-chain-tooling--developer-experience)
  - [13. TypeScript SDK (wagmi/viem from Foundry ABI)](#13-typescript-sdk-wagmiviem-from-foundry-abi)
  - [14. Subgraph + Ponder indexer](#14-subgraph--ponder-indexer)
  - [15. Multibase/multicodec key-encoding helper](#15-multibasemulticodec-key-encoding-helper)
  - [16. examples/ folder + end-to-end testnet tutorial](#16-examples-folder--end-to-end-testnet-tutorial)
  - [17. Docs site from NatSpec (forge doc)](#17-docs-site-from-natspec-forge-doc)
- [Theme D — Testing, Verification & Quality](#theme-d--testing-verification--quality)
  - [18. Symbolic verification with Halmos](#18-symbolic-verification-with-halmos)
  - [19. W3C conformance test vectors](#19-w3c-conformance-test-vectors)
  - [20. Mutation testing + Echidna/Medusa](#20-mutation-testing--echidnamedusa)
  - [21. Deterministic multichain deployments + verification](#21-deterministic-multichain-deployments--verification)
- [Theme E — Community, Discoverability & Governance](#theme-e--community-discoverability--governance)
  - [22. Draft an ERC for the on-chain DID method](#22-draft-an-erc-for-the-on-chain-did-method)
  - [23. Academic reproducibility & discoverability](#23-academic-reproducibility--discoverability)
  - [24. Developer onboarding & contributor funnel](#24-developer-onboarding--contributor-funnel)
- [Priority Matrix & Suggested Sequencing](#priority-matrix--suggested-sequencing)
- [Open Questions for Miguel](#open-questions-for-miguel)

---

## How to Read This

Ratings use a 1–5 scale. **Effort** = engineering + research time (1 = a day, 5 = multi-week/PhD-chapter).
**Impact** is split into **Community** (adoption/contributors) and **Research** (publishable novelty / academic credibility),
because this is a PhD project where both matter.

Several `[UNCERTAIN]` flags below come straight from the research dossiers — they mark claims to
re-verify against fast-moving specs (EntryPoint versions, DID 1.1 status, ERC-7562 rules) before
putting them in a paper.

## Current State (audit baseline)

What the audit confirmed already **exists**: solid dual-variant contracts, `isAuthorized` +
`isAuthorizedOffChain` (raw `ecrecover`), 8 lifecycle events, deployment scripts for ~20 chains,
>90% coverage with fuzz+invariant tests, CI (Slither, gas-diff, fmt), and the full governance doc set
(CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, CITATION, CHANGELOG).

What is **missing / weak** (the opportunity surface):
- **EOA-only auth.** No `ERC-1271`, no ERC-4337/smart-account awareness anywhere. *(Updated v1.4.0)*: `tx.origin` was removed from auth and ID generation — it survives only as the `onlyDirectEOA` equality guard (`msg.sender == tx.origin`); EOA-only auth remains (no `ERC-1271` yet).
- **No off-chain tooling at all** — no `package.json`, no JS/TS SDK, no subgraph, no resolver driver, no example dApp.
- **Ad-hoc signatures** — `validateVm` is a raw `vm.ethereumAddress == sender` check; `isAuthorizedOffChain` is raw `ecrecover(messageHash,v,r,s)` with **no EIP-191/EIP-712** domain separation.
- **No public deployment** — `.deployments.json` only records a private chain (id 6660); nothing verified on a public testnet.
- **Single hardcoded `@context`** (`https://www.w3.org/ns/did/v1`) and a non-registered method name (`lzpf`).

---

## Implementation Status

> Verified 2026-08-24 by a direct scan of the working tree (`find src test`, marker-file
> existence check, `forge build` + `forge test` → 325/325 passing on the default profile).
> Status values: **Done** (shipped and tested), **Partial** (some sub-goals shipped),
> **Not started** (no artifact exists in the repo).

| # | Idea | Status | Evidence |
|---|------|--------|----------|
| 1 | ERC-1271 / ERC-6492 controller sigs | **Partial** | `isAuthorizedOffChainWithSigner` shipped on both variants via OZ `SignatureChecker`; 21 tests in `test/unit/AuthorizeOffChainErc1271.unit.t.sol`. Missing: ERC-6492, and contract-owned VMs (see blocker below) |
| 2 | ERC-7579 DID validator module | Not started | no `DidValidator.sol` |
| 3 | EIP-7702 path + remove `tx.origin` | **Partial** | `tx.origin` purged from auth; `onlyDirectEOA` guard + `DirectEOACallRequired` shipped; `test/unit/DirectEOAGuard.unit.t.sol` (20 tests). Missing: mock-EntryPoint / smart-account test suite, EIP-7702 documentation |
| 4 | ERC-6551 token-bound subjects | Not started | — |
| 5 | Register DID method (W3C) | Not started | no `docs/spec/` |
| 6 | DIF Universal Resolver driver | Not started | — |
| 7 | did-resolver JS package | Not started | no `package.json` anywhere in the repo |
| 8 | Configurable `@context` | Not started | `W3CResolverBase` still builds a single hardcoded context |
| 9 | EIP-712 typed data | Not started | `isAuthorizedOffChain` still raw `ecrecover(messageHash,v,r,s)`, no domain separator |
| 10 | CAIP-10 / did:pkh import | Not started | — |
| 11 | EAS / Verax bridge | Not started | — |
| 12 | ethr-did benchmark | Not started | no comparison table in `docs/metrics/` |
| 13 | TypeScript SDK | Not started | no `packages/` |
| 14 | Subgraph + Ponder | Not started | no `subgraph/`, no `indexer/` |
| 15 | Multibase helper | Not started | — |
| 16 | `examples/` + tutorial | Not started | no `examples/` |
| 17 | Docs site (`forge doc`) | Not started | single CI workflow, no Pages job |
| 18 | Halmos symbolic verification | Not started | no halmos tests, no CI job |
| 19 | W3C conformance vectors | Not started | no `test/vectors/` |
| 20 | Mutation testing + Echidna | Not started | — |
| 21 | Public testnet deploys | Not started | `.deployments.json` still records only private chain 6660 |
| 22 | ERC draft | Not started | — |
| 23 | Zenodo / preprint / topics | Not started | `CITATION.cff` exists, no DOI |
| 24 | Onboarding / devcontainer | Not started | no `Makefile`, no `.devcontainer/`, no `docs/adr/` |

**Score: 2 of 24 partially done, 22 not started.** Only ideas #1 and #3 have touched code so far.

### Blocking conflict discovered during implementation

`onlyDirectEOA` (shipped in v1.4.0, idea #3) and the account-abstraction theme (#1, #2, #4)
pull in opposite directions. The guard rejects **every** call whose `msg.sender` is a contract,
so a smart account, multisig, or ERC-4337 bundler cannot execute any of the 8 authenticated
write entry points. Ideas #1/#2/#4 exist precisely to let those contracts act.

Three ways out, in order of preference:

1. **Signature-only AA (recommended, no contract-write change).** Contract controllers are
   supported through the *view* auth path (`isAuthorizedOffChain` + ERC-1271) and through the
   ERC-7579 module (#2), which reads DID state rather than writing it. Writes stay direct-EOA.
   Cheapest, preserves the confused-deputy fix, and is enough for the flagship thesis, because
   `validateUserOp` only ever *reads*.
2. **Per-DID opt-in.** A flag set at `createDid` time relaxes `onlyDirectEOA` for that DID.
   Restores full AA write access but reopens the confused-deputy class for opted-in DIDs and
   adds a storage slot.
3. **Drop the guard.** Maximum AA compatibility, discards the v1.4.0 security fix. Not advised.

This roadmap assumes **option 1** until decided otherwise. Idea #1's implementation below is
written against it: ERC-1271 is added to the view path only, and `onlyDirectEOA` is untouched.


### Second blocker: a contract cannot own a verification method

Found while implementing #1 (2026-08-24). Two rules combine to lock contracts out of VM ownership
entirely, independently of the `onlyDirectEOA` guard:

1. `VMStorage._createVm` (and the native equivalent) sets `command.expiration = 0` whenever
   `ethereumAddress != address(0)`, so an address-bound VM starts inactive.
2. `_validateVm` activates it only when `msg.sender == vm.ethereumAddress`, and the public
   `validateVm` entry point carries `onlyDirectEOA`.

A contract address therefore can never activate its own VM: it cannot be `msg.sender` through the
guard, and no one else may activate on its behalf. `_isAuthorized` rejects any VM with
`expiration == 0`, so ERC-1271 signatures from a contract-owned VM can never authorize.

What #1 delivers today is the **EIP-7702 shape**: an address validated while it was a plain EOA,
which later gains code. That covers upgraded-in-place wallets, which is the dominant 2025+ case,
but not a freshly deployed Safe or Kernel account.

Closing the gap needs a signature-based activation path, e.g.
`validateVmWithSignature(positionHash, expiration, bytes signature)` verifying the signature
against `vm.ethereumAddress` through `SignatureChecker`, so any EOA can relay the activation while
authority stays with the VM's own key. That is a **write**-path security change and is deliberately
left for an explicit decision rather than folded into #1.

### Sub-tasks left over from #3 (v1.4.0)

- Mock-EntryPoint + smart-account test suite proving auth behaviour under AA (currently the
  proof is only the confused-deputy mocks in `DirectEOAGuard.unit.t.sol`).
- Explicit EIP-7702 note in `PROJECT.md`: a 7702-delegated EOA still signs its own transaction,
  so `msg.sender == tx.origin` holds and the guard passes.


## Theme A — Account Abstraction & Smart-Account Identity

> This theme is the project's strongest **research** differentiator. The headline thesis (your example)
> is #2; #1 and #3 are the foundational steps that make it real and de-risk it.

### 1. ERC-1271 / ERC-6492 controller signatures (foundational)

**What.** Let a DID controller be a **smart contract** (multisig, smart account, social-recovery wallet),
not just an EOA. Verify controller signatures via `IERC1271.isValidSignature(hash, sig) == 0x1626ba7e`,
with an `ERC-6492` fallback for counterfactual (not-yet-deployed) accounts.

**Why.** Today every auth path does a literal `address ==` comparison (`VMStorage._isVmRelationship`,
`_isVmOwner`) or `ecrecover` (`isAuthorizedOffChain`). Under any smart wallet that model silently fails —
the controller cannot prove anything. ERC-1271 is the universal standard the entire AA stack already speaks.
This is the **prerequisite** for ideas #2 and #3.

**How.**
- Add an internal `_isValidSignature(address signer, bytes32 hash, bytes sig)` helper that does:
  `signer.code.length == 0 ? ecrecover-path : IERC1271(signer).isValidSignature(hash,sig) == 0x1626ba7e`.
  OpenZeppelin's `SignatureChecker` already implements exactly this (and is in `lib/`).
- Extend `isAuthorizedOffChain` to accept a `bytes signature` overload (not just `v,r,s`) so contract sigs fit, and route through `SignatureChecker`.
- For counterfactual wallets, accept ERC-6492-wrapped signatures (detect the `0x6492…6492` magic suffix) — or document that on-chain verification requires deployment first.

**Strengths.** Small, standards-clean, unlocks the whole AA theme. Backward-compatible (EOA path unchanged).
**Weaknesses.** ERC-1271 requires the controller be deployed (6492 mitigates but adds complexity). Contract-sig verification costs more gas; must guard against ERC-1271 re-entrancy in view contexts.
**Effort 2 · Community 3 · Research 3.**

### 2. ERC-7579 "DID Validator" module (flagship thesis)

**What.** Package the project's authentication logic (active `authentication` VM in the on-chain DID
document + non-expired DID + controller relationships) as a **reusable ERC-7579 validator module**.
The module's `validateUserOp()` becomes *the DID authentication checkpoint*, and its
`isValidSignatureWithSender()` answers ERC-1271 queries with the **same DID-document logic**. This is the
concrete, portable embodiment of your thesis: *the smart account is the DID controller, and the on-chain
W3C DID document is the policy enforced inside `validateUserOp`.*

**Why.** The research confirms this framing appears **un-claimed** in surveyed literature (closest prior art —
EugeRe's 2024 ethresear.ch thread — validates VCs at the *bundler/keystore* layer, off-chain; ERC-725/ONCHAINID
use key-purpose semantics, not W3C documents). Shipping a module that installs on **Kernel (ZeroDev), Nexus
(Biconomy), and Safe7579** turns the paper's contribution into a vendor-neutral artifact people can actually use —
the difference between a citation and a dependency.

**How.**
- New contract `DidValidator.sol` implementing ERC-7579 `IValidator` (type 1): `onInstall`, `onUninstall`,
  `validateUserOp(PackedUserOperation, userOpHash, missingAccountFunds) → validationData`,
  `isValidSignatureWithSender(address sender, bytes32 hash, bytes sig)`.
- Internally call the existing `isAuthorized`/VM-relationship logic against a configured `(methods, id)` DID.
  Pack `validUntil` from the DID/VM expiration into the returned `validationData` (huge win — the DID's
  4-year expiry becomes the UserOp validity window for free).
- Must NOT revert on bad sig — return `SIG_VALIDATION_FAILED (1)`.
- Test against Rhinestone's ModuleKit + the three reference accounts.

**Strengths.** Directly publishable novelty; maximum dissemination (one module → many wallets); reuses existing
`VMStorage`/`isAuthorized` almost verbatim.
**Weaknesses / Risks.** **[UNCERTAIN — biggest feasibility risk]** ERC-7562 alt-mempool storage rules may restrict
reading a *separate* DID registry contract during `validateUserOp` (anti-DoS). Mitigations: stake the registry,
keep DID state in the account's *associated* storage, or have the module cache an attestation. Verify this
**before** committing the design. Also: keeps you on a moving target (EntryPoint v0.9 current).
**Effort 5 · Community 4 · Research 5.**

### 3. EIP-7702 controller path + remove tx.origin from auth

> **Status (v1.4.0, 2026-06-10)**: the `tx.origin` → `msg.sender` migration + `onlyDirectEOA` guard **shipped** in v1.4.0. Remaining open: the ERC-1271 path (#1) and the AA test suite (mock EntryPoint + smart account).

**What.** Two linked moves. (a) Document & support EOA controllers that have "upgraded in place" via
**EIP-7702** (live since Pectra, May 2025) — they keep their address but gain smart-account behavior.
(b) **Purge `tx.origin` from authorization** (keep it, at most, as one entropy input to ID generation —
and even there, reconsider it).

**Why.** Under AA, `tx.origin` is the **bundler's** EOA, not the user — so all 8 `tx.origin` auth checks in
`DidAggregate`/`VMStorage` would mis-identify or reject the real controller. EIP-7702 also explicitly breaks
`require(tx.origin == msg.sender)` patterns. The current code comment "*uses tx.origin intentionally … preventing
intermediary contracts from impersonating*" is exactly the assumption AA invalidates. There is also a subtle
correctness note: ID generation hashes `tx.origin` — under AA that attributes the DID's entropy to the **bundler**,
not the subject. Entropy is fine; *attribution* is wrong.

**How.**
- Replace `tx.origin` with `msg.sender` in `DidAggregate` (lines ~81, ~92, ~273) and in `_validateVm` callers,
  combined with the ERC-1271 path from #1 so contract senders work.
- For ID generation, drop `tx.origin` in favour of `msg.sender` (the account) + user-supplied `random`; document
  the change as an explicit AA-compatibility decision in PROJECT.md.
- Add a test suite that drives operations *through* a mock EntryPoint + smart account to prove auth still holds.

**Strengths.** Makes the system correct under the dominant 2025+ wallet model; removes a known anti-pattern that
auditors/Slither flag. EIP-7702 means **no address migration** for existing EOA users — the biggest adoption tailwind.
**Weaknesses.** Behavioural change to a security-critical path → needs careful re-testing and a CHANGELOG breaking note.
Some standalone-EOA flows relied on `tx.origin == signer`; those semantics shift to `msg.sender`.
**Effort 3 · Community 4 · Research 4.**

### 4. ERC-6551 token-bound-account DID subjects (research track)

**What.** Allow a DID subject to be an **NFT**, with its ERC-6551 token-bound account as the controller —
so transferring the NFT transfers the whole identity ("identity backpack").

**Why.** A clean, portable, role/seat-based identity primitive (org roles, AI agents, avatars). No surveyed source
ties ERC-6551 to *W3C DID documents* specifically — a small but genuine research seam.

**How.** A thin adapter that resolves an NFT `(chainId, tokenContract, tokenId)` → ERC-6551 account address →
uses that account as the DID controller (reuses #1's ERC-1271 path, since the reference 6551 account is ERC-1271).

**Strengths.** Novel angle; demos well. **Weaknesses.** Transferability is *wrong* for human SSI (you usually want
soulbound/non-transferable); scope it as an explicit "transferable identity" variant, not the default. Niche.
**Effort 3 · Community 2 · Research 3.**

---

## Theme B — Standards Alignment & Interoperability

### 5. Register the DID method in the W3C registry

**What.** Pick a real method name (the code uses `lzpf` as default `methods`), write a **DID method
specification**, and PR it into `w3c/did-extensions` (the DID Spec Registries). Listing requires only a unique
name + a published spec — **no standards-track approval**.

**Why.** Until the method is registered with a spec, no resolver, wallet, or paper can treat it as a real DID
method — it's "some contract." Registration is the cheapest credibility/interop unlock available.

**How.** Author `docs/spec/did-method-ssiobc.md` covering the method name, Method-Specific Identifier syntax
(your `did:method0:method1:method2:id`), and CRUD operations mapped to contract calls; open the registry PR.
Decide naming: a single canonical name (e.g. `did:ssiobc`) is more registry-friendly than the 3-segment `lzpf::main::` default.
**Strengths.** Low effort, high legitimacy; precondition for #6. **Weaknesses.** The 3-level method structure is unusual
and may invite registry reviewer questions — be ready to justify it. **Effort 2 · Community 4 · Research 3.**

### 6. DIF Universal Resolver driver

**What.** A Docker container answering `GET /1.0/identifiers/{did}` that returns the DID document, then PR it into
the DIF `universal-resolver` repo (edit `docker-compose.yml` / `application.yml`, pin an image version).

**Why.** The Universal Resolver is *the* aggregator wallets and SSI stacks query. Being listed there means anyone
resolving `did:ssiobc:…` gets your document with zero bespoke integration.

**How.** Wrap the JS resolver from #7 in a tiny HTTP server (the DIF driver template), Dockerize, version-pin,
PR. Requires #5 (registered method) and #7 (resolver) first.
**Strengths.** Global reach. **Weaknesses.** Needs a hosted RPC endpoint per chain; DIF review latency.
**Effort 2 · Community 4 · Research 2.**

### 7. did-resolver-compatible JS resolver (unlocks Veramo)

**What.** An npm package exposing `getResolver() → { ssiobc: resolveFn }`, where `resolve(did, parsed, …)` returns
a standard `DIDResolutionResult` (`didResolutionMetadata` / `didDocument` / `didDocumentMetadata`). It reads the
on-chain document via the W3CResolver contract (or the subgraph from #14).

**Why.** This **one** package is the highest-leverage interop deliverable: it instantly unlocks **Veramo**
(`DIDResolverPlugin` wraps a plain `Resolver`), **did-jwt-vc** (`verifyCredential(jwt, { resolver })`), and the
Universal Resolver (#6). It's the bridge from "Solidity contract" to "thing the SSI ecosystem can consume."

**How.** TS package `@ssiobc/did-resolver` depending on `did-resolver` + `viem`; map the on-chain
`W3CDidDocument` struct to JSON-LD. Ship dual ESM/CJS via tsup.
**Strengths.** Maximum ecosystem leverage per line of code. **Weaknesses.** Must track the contract's struct shape;
on-chain `resolve()` can be gas-heavy for big documents (mitigate with the indexer, #14).
**Effort 3 · Community 5 · Research 2.**

### 8. Configurable @context + DID 1.1 / VC 2.0

**What.** Make the JSON-LD `@context` configurable instead of the single hardcoded
`https://www.w3.org/ns/did/v1` (`W3CResolverBase.sol:40`), and align with **DID 1.1** (now CR, layered on
Controlled Identifiers v1.0) and **VC Data Model 2.0** (Rec, May 2025).

**Why.** A fixed v1 context blocks credential contexts and future-proofing. Proper, extensible contexts are what
make documents validate in conformance tools and consume cleanly in VC pipelines.

**How.** Store `@context` as a settable array (constructor param or governed setter) and emit it through the
resolver; default to `["https://www.w3.org/ns/did/v1"]` but allow appends.
**Strengths.** Cheap, improves conformance. **Weaknesses.** [UNCERTAIN] DID 1.1 / VC 2.0 statuses move fast — verify before claiming compliance. **Effort 1 · Community 3 · Research 3.**

### 9. EIP-712 typed data for signatures

**What.** Replace the raw `ecrecover(messageHash, v, r, s)` in `isAuthorizedOffChain` and the bare
`vm.ethereumAddress == sender` check in `validateVm` with **EIP-712 typed, domain-separated signatures**
(with a chainId + verifyingContract domain) — and align with **SIWE/CACAO** for off-chain login flows.

**Why.** The current `messageHash` is opaque and has **no domain separation** → cross-contract / cross-chain
**replay risk** and poor wallet UX (users sign an unreadable hash). EIP-712 gives human-readable signing,
replay protection, and is the SSI/AA norm.
**How.** Define `DidAuthorization` and `VmValidation` EIP-712 structs + `DOMAIN_SEPARATOR`; use OZ `EIP712` +
`ECDSA`. Combine with #1 so `SignatureChecker` covers both EOA and contract signers. Add a `nonce` per DID to kill replay.
**Strengths.** Security hardening + UX; composes with #1. **Weaknesses.** ABI/signature-format change → version bump and SDK update.
**Effort 3 · Community 3 · Research 4.**

### 10. CAIP-10 + did:pkh import + did:ethr interop

**What.** Lean into chain-agnostic identifiers: ensure `blockchainAccountId` uses **CAIP-10** consistently
(it already targets `eip155:1:0x…`), add a **did:pkh → SSIoBC import** path (bootstrap a document from an
existing address-based DID), and document interop with **did:ethr / ERC-1056**.

**Why.** did:pkh/did:ethr are the incumbents; an on-ramp from them lowers switching cost and positions SSIoBC as
"the upgrade that adds a *stored, queryable* on-chain document."
**How.** A helper that takes a CAIP-10 account → creates a DID with that address as the initial `authentication` VM.
Document CAIP-2 chain refs in the resolver output.
**Strengths.** Adoption bridge; strong paper narrative (migration story). **Weaknesses.** Mostly docs+helper, limited novelty. **Effort 2 · Community 3 · Research 2.**

### 11. EAS / Verax attestation bridge

**What.** Bridge to **Ethereum Attestation Service** (and Verax): represent verifiable claims about a DID as
on-chain EAS attestations referencing the DID, and/or resolve EAS attestations into the document's services/claims.

**Why.** EAS is the pragmatic, widely-deployed on-chain analog of Verifiable Credentials. A DID + attestation
combo is far more useful (and demo-able) than DIDs alone, and connects you to an active ecosystem.
**How.** Define an EAS schema keyed on `idHash`; a small contract/SDK helper to issue & query. Optionally surface
attestations as W3C VCs via #7.
**Strengths.** Real-world utility, ecosystem gravity. **Weaknesses.** Scope creep risk — keep it an optional module.
**Effort 3 · Community 3 · Research 3.**

### 12. ethr-did benchmark + migration adapter

**What.** A rigorous, published **head-to-head** vs ERC-1056/ethr-did (the dominant EVM DID method): gas cost
(create / add-key / resolve), storage model, resolution latency, and feature matrix — plus a thin adapter that
can resolve an ethr-did into the SSIoBC document shape.

**Why.** The project's central claim is "fully on-chain *stored* document vs ethr-did's *event-reconstructed*
document." That claim is only persuasive with **numbers**. This is both a community artifact and a paper table.
**How.** Foundry gas benchmarks (you already have `gas-diff` CI) producing a committed comparison table in
`docs/metrics/`; a small TS comparison harness for resolution latency.
**Strengths.** Directly supports the innovation claim with evidence. **Weaknesses.** Fair benchmarking is finicky
(event-based resolution cost is off-chain — compare honestly). **Effort 3 · Community 3 · Research 4.**

---

## Theme C — Off-chain Tooling & Developer Experience

> The single biggest community gap: **there is no client tooling at all.** A smart contract no one can call
> from JavaScript is, practically, invisible. This theme is where adoption is won or lost.

### 13. TypeScript SDK (wagmi/viem from Foundry ABI)

**What.** A typed TS SDK generated from the Foundry ABIs (`out/`) via **wagmi CLI + `@wagmi/cli` foundry plugin**
(viem/ABIType inference), wrapping the awkward low-level calls (everything is `bytes32 methods, bytes32 id, …`)
in ergonomic functions: `createDid()`, `addVerificationMethod()`, `resolve()`, `authorize()`.

**Why.** The contract API is *hostile* to humans (packed `bytes32` methods, position hashes, manual `v,r,s`).
A good SDK is the difference between "interesting research" and "I shipped a dApp with it this afternoon."
Copy the ethr-did 4-package split: contracts / resolver / high-level SDK / driver.
**How.** `packages/sdk` with wagmi-codegen; helpers for DID string ↔ `(methods,id)` parsing, multibase encoding
(#15), and signature building (#9). Publish `@ssiobc/sdk` to npm; ship a separate `@ssiobc/contracts` (ABIs+addresses).
**Strengths.** Force-multiplier for *every* other community idea (#16, #6, #7 all consume it).
**Weaknesses.** Ongoing maintenance burden; must version in lockstep with contracts. **Effort 4 · Community 5 · Research 1.**

### 14. Subgraph + Ponder indexer

**What.** Index the 8 lifecycle events (`DidCreated`, `VmCreated`, `VmValidated`, `ControllerUpdated`,
`ServiceUpdated`, …) into a queryable store — ship **both** a The Graph subgraph (reach) and a **Ponder** template
(10× faster sync, self-hostable, reuses TS).

**Why.** On-chain `resolve()` is fine for one document but expensive for discovery/listing/history. The events are
already well-indexed (`idHash`, `id` are indexed params) — feasibility is high. Fast off-chain resolution makes the
JS resolver (#7) and any dApp snappy.
**How.** `subgraph/` with `subgraph.yaml` + GraphQL schema keyed on `idHash`; `indexer/` Ponder config mirroring it.
**Strengths.** Unlocks performant resolution/analytics; near-free given existing events. **Weaknesses.** One more
deployment to host; subgraph and contract must stay in sync. **Effort 3 · Community 4 · Research 2.**

### 15. Multibase/multicodec key-encoding helper

**What.** A small JS lib (or part of the SDK) that produces the `publicKeyMultibase` strings the contracts
*require to be pre-encoded off-chain* (must start with `z`, base58btc, multicodec-prefixed).

**Why.** The contracts deliberately push Base58/multicodec encoding off-chain for gas. But there's currently **no
helper to do it**, so a user literally cannot construct a valid VM without hand-rolling multiformats. This is a
silent adoption blocker.
**How.** Wrap `multiformats` (`base58btc` + varint multicodec, e.g. `0xe701` secp256k1, `0xed01` Ed25519) or
`@digitalbazaar/*-multikey`. Provide `encodeMultibase(pubkey, keyType)` and the inverse.
**Strengths.** Tiny, removes a hard blocker. **Weaknesses.** Must match exactly what the resolver expects
(test round-trips against contract). **Effort 1 · Community 4 · Research 1.**

### 16. examples/ folder + end-to-end testnet tutorial

**What.** A runnable `examples/` directory: "create a DID, add a key, issue a credential, resolve it" against a
public testnet, plus a written walkthrough.

**Why.** Examples are how developers evaluate a project in 10 minutes. Right now there is no path from `git clone`
to a working DID besides reading Solidity tests.
**How.** Node scripts using the SDK (#13) against a deployed testnet (#21); a Foundry script variant too. Link from README.
**Strengths.** Converts curiosity → usage; doubles as integration tests. **Weaknesses.** Depends on #13 + #21 existing.
**Effort 2 · Community 4 · Research 1.**

### 17. Docs site from NatSpec (forge doc)

**What.** Generate an API/reference docs site from existing NatSpec via `forge doc` (mdBook) — or a Docusaurus/Vocs
site — published to GitHub Pages in one CI job. Fold in the PROJECT.md mermaid diagrams.

**Why.** The docs are excellent but trapped in two giant markdown files. A browsable site with the architecture
diagrams + auto API reference massively lowers the onboarding cliff and looks credible.
**How.** `forge doc --build`; CI job → Pages. Optionally a Vocs landing page that embeds the diagrams + quickstart.
**Strengths.** Near-free given NatSpec coverage requirement already enforced. **Weaknesses.** Yet another surface to keep current. **Effort 2 · Community 3 · Research 2.**

---

## Theme D — Testing, Verification & Quality

### 18. Symbolic verification with Halmos

**What.** Add **Halmos** symbolic tests over the authorization invariants (e.g. "no path lets a non-controller,
non-owner pass `isAuthorized`"; "an expired VM never authenticates"). Reuses your existing Foundry tests — no new
language, no new keys.

**Why.** For an *identity/auth* contract, "we fuzzed it" is good; "we symbolically proved the core auth properties
(bounded)" is a paper-grade credibility jump, at low marginal effort.
**How.** `halmos` tests in `test/` mirroring invariant properties; add a CI job. Frame honestly as **bounded** symbolic
verification. Optionally Certora later (license-gated).
**Strengths.** High credibility-per-effort; targets the most security-sensitive code. **Weaknesses.** Symbolic tools
choke on heavy keccak/dynamic bytes — may need to scope to the auth core. **Effort 3 · Community 2 · Research 4.**

### 19. W3C conformance test vectors

**What.** Ship in-repo **test vectors** (canonical DID input → expected DID-document JSON-LD) and run the
`w3c/did-test-suite` against the resolver output.

**Why.** For a DID paper this is *the* single most credibility-defining artifact — it turns "W3C-compliant" from a
claim into a verifiable, reproducible fact. Also catches resolver regressions.
**How.** `test/vectors/*.json`; a script that resolves on-chain and diffs against expected; wire into CI. Target DID 1.1.
**Strengths.** Converts the headline compliance claim into evidence. **Weaknesses.** JSON-LD canonicalization is fiddly;
on-chain → JSON bridge needed (use #7). **Effort 3 · Community 3 · Research 5.**

### 20. Mutation testing + Echidna/Medusa

**What.** Add **mutation testing** (Gambit or vertigo-rs) to report a defensible *mutation score*, and layer
**Echidna/Medusa** property fuzzing alongside the existing Foundry invariants.

**Why.** >90% line coverage says lines *ran*, not that tests *catch bugs*. A mutation score is a stronger,
publishable quality metric; a second fuzzer finds what the first misses (diversity).
**How.** Gambit config over `src/`; a CI (or nightly) job reporting surviving mutants; Echidna config reusing invariant properties.
**Strengths.** Stronger quality evidence than coverage alone. **Weaknesses.** Mutation runs are slow (nightly, not per-PR); tuning noise. **Effort 3 · Community 2 · Research 3.**

### 21. Deterministic multichain deployments + verification

**What.** Deploy to public testnets (**Sepolia**, **Hoodi** — Holesky's successor) with **CREATE2 deterministic
same-address-multichain** addresses, verify on **Etherscan + Sourcify**, and maintain a real `deployments.json`
registry (today only private chain 6660 is recorded).

**Why.** "Here's the verified contract at the same address on N chains, go try it" is the credibility and adoption
unlock that a private-chain-only deployment can't give. Required by #6, #7, #16.
**How.** CREATE2 factory deploy; pin `bytecode_hash="none"` + fixed solc/evm_version for reproducible bytecode;
verify; commit addresses. **[UNCERTAIN]** confirm target testnets support the `evm_version` ("Osaka") the project pins — may need a more conservative target for public deploys.
**Strengths.** Foundational for all client tooling; same-address UX. **Weaknesses.** The Osaka/Fusaka evm_version pin may not be supported on all public testnets yet — could force a separate deploy profile. **Effort 3 · Community 4 · Research 2.**

---

## Theme E — Community, Discoverability & Governance

### 22. Draft an ERC for the on-chain DID method

**What.** Write an **ERC/EIP draft** specifying the fully-on-chain DID document standard, explicitly contrasting
with **ERC-1056** (event-based). Even as a Draft, it's a magnet for review and collaborators.

**Why.** An ERC is how EVM standards get discovered, debated, and adopted. The natural framing — "stored,
queryable W3C document vs reconstructed-from-events" — is a clear, defensible delta from the incumbent.
**How.** Use the EIP template; reference the method spec (#5) and benchmarks (#12). Socialize on Ethereum Magicians.
**Strengths.** High visibility, durable artifact, strong thesis support. **Weaknesses.** Standards process is slow and
opinionated; expect pushback on full-on-chain storage cost. **Effort 4 · Community 4 · Research 4.**

### 23. Academic reproducibility & discoverability

**What.** Mint a **Zenodo DOI** for tagged releases (GitHub→Zenodo integration), publish a preprint (arXiv) with a
**reproducible artifact** (one-command rebuild of all gas/coverage/benchmark numbers), add **GitHub topics**
(`did`, `ssi`, `w3c`, `ethereum`, `account-abstraction`, `verifiable-credentials`), and submit to relevant
**awesome-lists** (awesome-did, awesome-ssi).
**Why.** Near-free citability + discoverability. A DOI makes the software itself citable; topics/awesome-lists are how
people *find* it; a reproducible artifact is increasingly expected by venues.
**How.** Enable Zenodo on the repo; `make reproduce` regenerating `docs/metrics/`; PRs to awesome-lists.
**Strengths.** Cheap, compounding. **Weaknesses.** Preprint takes writing time (but the docs are 80% there).
**Effort 2 · Community 3 · Research 4.**

### 24. Developer onboarding & contributor funnel

**What.** A **devcontainer**/Nix flake + a `Makefile`/`justfile` one-command quickstart (`make setup && make test`),
"good first issue" labels, an issue/discussion template set, and a short architecture-decision-record (ADR) log.
**Why.** The repo has CONTRIBUTING.md but no *frictionless* path to a green test run, and no curated on-ramp for
new contributors. Lowering "time to first passing build" is the strongest predictor of external contributions.
**How.** `.devcontainer/` with Foundry preinstalled; `Makefile` targets; label a handful of scoped issues; add
`docs/adr/`.
**Strengths.** Converts visitors → contributors; low effort. **Weaknesses.** Needs ongoing issue curation to stay alive.
**Effort 1 · Community 4 · Research 1.**

---

## Priority Matrix & Suggested Sequencing

| # | Idea | Effort | Community | Research | Tier | Status |
|---|------|:--:|:--:|:--:|---|---|
| 1 | ERC-1271/6492 controller sigs | 2 | 3 | 3 | **Do first** | Partial |
| 3 | EIP-7702 + remove tx.origin | 3 | 4 | 4 | **Do first** | Partial (v1.4.0) |
| 13 | TypeScript SDK | 4 | 5 | 1 | **Do first** | Not started |
| 15 | Multibase helper | 1 | 4 | 1 | **Quick win** | Not started |
| 21 | Public testnet deploys | 3 | 4 | 2 | **Do first** | Not started |
| 7 | did-resolver JS pkg | 3 | 5 | 2 | **High value** | Not started |
| 5 | Register DID method | 2 | 4 | 3 | **Quick win** | Not started |
| 9 | EIP-712 signatures | 3 | 3 | 4 | High value | Not started |
| 14 | Subgraph + Ponder | 3 | 4 | 2 | High value | Not started |
| 19 | W3C conformance vectors | 3 | 3 | 5 | **Research-critical** | Not started |
| 2 | ERC-7579 DID module | 5 | 4 | 5 | **Flagship** | Not started |
| 12 | ethr-did benchmark | 3 | 3 | 4 | Research-critical | Not started |
| 18 | Halmos verification | 3 | 2 | 4 | Research | Not started |
| 22 | ERC draft | 4 | 4 | 4 | Strategic | Not started |
| 8 | Configurable @context | 1 | 3 | 3 | Quick win | Not started |
| 17 | Docs site | 2 | 3 | 2 | Quick win | Not started |
| 24 | Onboarding/devcontainer | 1 | 4 | 1 | Quick win | Not started |
| 16 | examples/ + tutorial | 2 | 4 | 1 | After SDK | Not started |
| 23 | Zenodo/preprint/topics | 2 | 3 | 4 | Quick win | Not started |
| 6 | Universal Resolver driver | 2 | 4 | 2 | After 5+7 | Not started |
| 10 | CAIP-10/did:pkh import | 2 | 3 | 2 | Nice-to-have | Not started |
| 11 | EAS/Verax bridge | 3 | 3 | 3 | Optional module | Not started |
| 20 | Mutation + Echidna | 3 | 2 | 3 | Nice-to-have | Not started |
| 4 | ERC-6551 subjects | 3 | 2 | 3 | Research track | Not started |

**Suggested phasing:**
1. **Foundation (unblocks everything):** #15 → #13 → #21 → #5. Now the contracts are usable and public.
2. **AA core (the thesis):** #1 → #3 → #9, then the flagship **#2** once #1 lands. Verify ERC-7562 rules first.
3. **Interop & reach:** #7 → #14 → #6 → #8.
4. **Research credibility:** #19 → #12 → #18 → #22 → #23.
5. **Polish & community:** #17, #24, #16, then optional #4/#10/#11/#20.

## Open Questions for Miguel

1. **Method naming:** keep the 3-segment `did:method0:method1:method2:id` design, or adopt a single canonical
   `did:ssiobc:…` for registry/interop friendliness? (Affects #5, #6, #7.)
2. **AA scope for the paper:** is the deliverable the *thesis + prototype* (#2 as a research artifact), or a
   production-grade module shipped to Kernel/Nexus/Safe? That changes effort on #2 by a lot.
3. **`tx.origin` migration:** OK to make the auth path a **breaking change** (#3), or must v1 EOA semantics be
   preserved alongside the new AA path?
4. **Maintenance appetite:** an SDK + subgraph + resolver are *ongoing* commitments. Is there capacity to maintain
   npm packages, or should these be reference implementations explicitly marked "research-grade"?
5. **Verify-before-publish:** several novelty/feasibility claims are `[UNCERTAIN]` (ERC-7562 storage rules for #2;
   DID 1.1 status for #8; Osaka evm_version on public testnets for #21; literature novelty for #2). Want me to run a
   targeted verification pass on any of these next?
```
