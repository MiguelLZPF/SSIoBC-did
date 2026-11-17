# Contract Address as a Validated Verification Method (v1.8.0 design, Phase 1)

**Status**: approved by the owner on 2026-11-17 (D1 = A, D2 = A, D3 = A). Phase 2 implemented on the branch (code, tests and docs), not released. All decisions taken (D5 = B, D6 = A).
**Visual summary**: [contract-vm-validation-map.html](./contract-vm-validation-map.html) (generator: `contract-vm-validation-map.py`).
**Date**: 2026-11-17. **Base**: `main` 69715b6 (v1.7.0 source). **Branch**: `feat/contract-vm-validation`.

## Table of Contents

- [Verdict](#verdict)
- [Context](#context)
- [How Evidence Is Tagged](#how-evidence-is-tagged)
- [The Core Argument](#the-core-argument)
- [Answers to the Ten Points](#answers-to-the-ten-points)
- [Alternatives Compared](#alternatives-compared)
- [Decisions for the Owner](#decisions-for-the-owner)
- [Ranked Findings](#ranked-findings)
- [Reactivation Fix](#reactivation-fix)
- [Phase 2 Outline](#phase-2-outline)
- [What the Other Repositories Must Change](#what-the-other-repositories-must-change)
- [Not Covered](#not-covered)
- [Decision Log](#decision-log)

## Verdict

1. **The idea is valid.** A contract can hold an active verification method (VM) without giving
   anyone power over a DID they do not control. No probe found such a path.
2. **The proposal as written (validation by the contract's `owner()`) is safe with changes.** The
   changes are the five hardening rules in [point 5](#5-the-owner-call). It has no security hole we
   could not close. It has one functional gap: a contract whose owner is itself a contract (a
   multisig, a timelock, a DAO) can never be validated.
3. **A simpler alternative reaches the same goal and is recommended: remove `onlyDirectEOA` from
   `validateVm` only.** The contract validates itself. No call to foreign code, 8 bytes smaller
   instead of about 100 bytes larger, and contract-owned contracts work. The price has two parts.
   The project's statement "all 8 write entry points are guarded" becomes "7 of 8", which reverses
   a position recorded in the roadmap. And consent becomes "the code at that address made the
   call", which is wider than "an owner signed a transaction"
   ([the case against (a)](#alternatives-compared)). That is the owner's decision
   ([D1](#decisions-for-the-owner)).
4. An independent review found no path to power over a foreign DID under either option. It
   corrected three statements of the first draft; all are fixed here
   ([Ranked Findings](#ranked-findings)).

## Context

The SSIoBC framework needs an issuer contract: a contract of DID B that runs its own validation
logic and calls `VClaimManager.issueClaim` in B's name. `issueClaim` authorizes with
`DidManager.isAuthorized(..., 0x02, msg.sender)` (SSIoBC-vclaim, file `VClaimManager.sol` line 385), so the
contract's address has to be an active VM of B with assertionMethod.

Today that cannot happen. A VM bound to an address is created inactive and becomes active only when
that address calls `validateVm`, and `validateVm` carries `onlyDirectEOA`
(`src/DidAggregate.sol` line 79). EIP-7702 was rejected as the path, because the account's key can always
bypass the delegate's logic. The roadmap already names this gap ("Second blocker",
`docs/analysis/improvement-roadmap.md` lines 149 to 170) and sketches a signature-based fix; that sketch is
alternative (b) below.

## How Evidence Is Tagged

| Tag | Meaning |
|---|---|
| verified | observed on 2026-11-17 by a test that ran; the test source and its raw output are committed |
| read | read in source at the cited file and line, at 69715b6 |
| assumed | reasoning, not run; the sentence says what would break if it is wrong |

Committed evidence, all in `docs/assets/data/contract-vm-validation/`:

| # | File | What it is |
|---|---|---|
| 1 | `probe-unpatched.t.sol.txt`, `probe-unpatched-results.txt` | 26 tests on unchanged source (13 per variant) |
| 2 | `proto-owner-call.patch`, `.t.sol.txt`, `-results.txt` | prototype of the proposal (c), 21 tests: 17 Full, 4 Native (`c1`, `c2`, `c4`, `c5`) |
| 3 | `proto-guard-removed.patch`, `.t.sol.txt`, `-results.txt` | prototype of alternative (a), 16 tests (8 per variant) |
| 4 | `measurements.txt` | sizes, gas, suite results, raw precompile returns |

Cases are cited by the number in the test name: "evidence 1 case 3" is `test_case3_*` in file 1,
"evidence 2 c8" is `test_c8_*` in file 2, "evidence 3 case 5" is `test_Case5_*` in file 3.

The test files carry a `.txt` suffix so the build does not compile them. To reproduce: copy one to
`test/unit/` without the suffix, apply the matching patch if there is one, and run
`forge test --match-path` on it.

## The Core Argument

Authority over a DID comes from one place: a controller of the DID calls `createVm` and names an
address and its relationship bits. That call is a guarded, authenticated write and this design does
not touch it.

Validation is a second step with a different job. It records that the named address accepts the
role. It protects the address (a stranger cannot make my address an active key of their DID) and it
protects the controller from a typo. It gives the validator no power: after validation, the only
address that passes `_isAuthorized` is the VM's own address (`src/DidAggregate.sol` line 446, read).
The validator does pick the expiration, which is the one lever it has ([point 8](#8-who-may-validate)).

So the question for every alternative is narrow: **who may give consent for a contract address?**
A wrong answer lets a contract become a key of a DID *whose controller already named it*. It never
lets anyone act on a DID they do not control. Verified for (a): a victim contract forced to
validate as a key of the attacker's DID gets `isAuthorized` false on the victim's DID in three
shapes (evidence 3 case 5), and an open-call contract validated by a stranger still fails the 7
guarded writes (evidence 3 case 4). For (c) the same follows from the code: the patch changes who
may set the VM's expiration and nothing in `_isAuthorized` (read, `proto-owner-call.patch`).

## Answers to the Ten Points

### 1. Premise

1. A contract cannot validate today. A contract that is the VM's address and calls `validateVm`
   reverts `DirectEOACallRequired`; an EOA that is not the VM's address reverts `InvalidSignature`.
   Verified on both variants (evidence 1, cases 1a and 1b).
2. Once validated, `isAuthorized(..., bit, contractAddress)` returns true for each of the five
   bits and false for an unrelated address. Verified on both variants (evidence 1, case 2; the
   validation was simulated with a two-argument prank, and done for real in evidence 2 and 3).
3. `_isAuthorized` has no EOA rule. Read, `src/DidAggregate.sol` lines 426 to 450.

### 2. Reach of a contract key

Every function in the three contracts that a contract holding a validated VM could call with
success, by bit. DID rows are verified (evidence 1, case 3); VClaim and Trust rows are read at
SSIoBC-vclaim 2572606 (branch `feat/trust-integration`) and SSIoBC-trust b5d6a25.

| # | Bit | DidManager (both variants) | VClaimManager | TrustManager |
|---|---|---|---|---|
| 1 | `0x01` authentication | no write (all guarded); views only | none | `setTrust`, `removeTrust` (SSIoBC-trust, file `TrustManager.sol` lines 43, 81 and 208) |
| 2 | `0x02` assertionMethod | views only | `issueClaim`, `issueClaims`, `revokeClaim`, `revokeClaims` (`:94,108,127,136`) | none |
| 3 | `0x04`, `0x08`, `0x10` | views only | none | none |

"Views only" means `isAuthorized`, `isVmRelationship` and `isAuthorizedOffChainWithSigner` (point 4).
The reach extends to every DID that B controls, because `_isAuthorized` ends with
`_isControllerFor`. That is the same rule an EOA key has.

**Should contract keys be limited to some bits?** No limit in the DID contract; it is the
controller's choice. Reasons:

1. The repository's own test for a new `revert` (CLAUDE.md, Validation Scope): can a malformed value
   let someone act on a DID they do not control? A contract key with `0x01` cannot. The controller
   chose it.
2. A limit cannot be amended later, and a trust list driven by a contract (a DAO, a registry) is a
   plausible wish for `setTrust`.
3. If SSIoBC-trust wants `setTrust` to be EOA-only, the place for that rule is TrustManager, which
   owns the function.

One consequence the docs must state: a contract key can never perform a DID write, so **a DID must
keep at least one EOA authentication key**. A DID whose only live `0x01` keys are contracts cannot
expire a key, add a key or deactivate itself until its 4-year expiry. `createDid` always starts
with an EOA key, so this state is reached only by the owner expiring it. It harms only that owner.

### 3. DID writes stay closed

A validated contract holding all five bits called each of the 8 guarded functions directly, through
one extra contract hop, and through `delegatecall` to a helper. All 24 calls reverted
`DirectEOACallRequired`. Verified on both variants (evidence 1, cases 3a to 3c).

Why no chain of calls can pass: the guard needs `msg.sender == tx.origin`. `tx.origin` is the account
that signed the transaction, and EIP-3607 rejects transactions from an address that has code, with
the single exception of an EIP-7702 delegation. A plain contract therefore can never be
`tx.origin`. (assumed for the EIP-3607 part: it is a protocol rule, not tested here; if a chain does
not enforce EIP-3607 the existing guard is already weaker there, with or without this change.)

Under alternative (a) the list is 7 functions, not 8: `validateVm` is opened on purpose, and the
other 7 still revert (evidence 3, cases 4 and 8, verified).

An EIP-7702 account is not a "contract with a validated VM" in this sense: it has a key, it can be
`tx.origin`, and it can already perform all 8 writes today. That is the documented limit of the
guard (`src/DidAggregate.sol` lines 51 to 58) and no option changes it for the 7 document writes.

### 4. Off-chain paths

What opens: `isAuthorizedOffChainWithSigner` returns true for `signer = contract` when the contract
has a validated VM **and** its `isValidSignature` returns the ERC-1271 magic value. Verified:
true for an ERC-1271 wallet, false for a rejecting wallet and for a contract with no
`isValidSignature` (evidence 1, cases 4a, 4c, 4d).

What does not open: `isAuthorizedOffChain` (the `v, r, s` overload) stays false. It recovers the
signing EOA, which is not the contract (evidence 1, case 4b, verified).

Is it wanted? The changelog does not call this closed on purpose. It calls it a "Known gap"
(`CHANGELOG.md:334`) and the roadmap lists contract-owned VMs as the missing half of idea #1
(`docs/analysis/improvement-roadmap.md` line 99). So it is the documented goal. It opens only for
contracts that implement ERC-1271; an issuer contract that does not implement it stays closed on
this path. No sibling contract calls this view today (read: VClaimManager and TrustManager call
`isAuthorized` only). The existing caveat stays: `messageHash` is opaque, so replay protection is
the relying party's job. Owner decision [D3](#decisions-for-the-owner).

### 5. The `owner()` call

This point applies to the proposal (c) only. Alternative (a) makes no external call.

The prototype (evidence 2, `proto-owner-call.patch`) accepts the caller when the VM's address has
code and a hardened call to `owner()` returns the caller. The five rules that make it safe:

1. `staticcall`, so the target cannot write state or re-enter with effect.
2. A gas cap of 30,000, so a hostile target cannot burn the caller's gas.
3. Output buffer of 32 bytes and `returndatasize == 32`, so a large return costs nothing.
4. Compare the full 32-byte word with the caller, never a truncated address.
5. Require `code.length > 0` first.

Results, all verified in evidence 2. The "Test" column names the test; "F+N" ran on both variants,
"F" on the Full variant only. The prototype's one changed line is the same in both storage files,
but the Native rows marked "F" are not yet proven by a run; if D1 = B, Phase 2 runs every case on
both.

| # | Case | Result | Test | Variant |
|---|---|---|---|---|
| 1 | OpenZeppelin `Ownable`, owner calls | validated, `isAuthorized` true | `c1` | F+N |
| 2 | other EOA calls | `InvalidSignature` | `c1` | F+N |
| 3 | address with no code; CREATE2 address not yet deployed | `InvalidSignature`; succeeds after deployment | `c2` | F+N |
| 4 | precompiles `0x02`, `0x03`, `0x04` | `InvalidSignature` | `c3` | F |
| 5 | `owner()` reverts; returns 0, 31 or 64 bytes | `InvalidSignature` | `c4` | F+N |
| 6 | returned word has a high bit set | `InvalidSignature` | `c5` | F+N |
| 7 | `owner()` loops forever; returns 1 MB | `InvalidSignature`; whole call costs 64,683 gas in both cases | `c6` | F |
| 8 | `owner()` writes storage | `InvalidSignature` | `c7` | F |
| 9 | proxy (ERC-1967) in front of an owned implementation | validated by the owner | `c10` | F |
| 10 | `owner()` returns `msg.sender` | `InvalidSignature` (the caller there is the manager) | `c8_sender` | F |
| 11 | `owner()` returns `tx.origin` | **any EOA validates** | `c8_origin` | F |
| 12 | owner is a contract (multisig mock) | **cannot validate**, `DirectEOACallRequired` | `c9` | F |
| 13 | EIP-7702 account whose delegate has an `owner()` | **the delegate's owner validates for the account** | `c11` (etch and real delegation) | F |

Rules 4 and 5 are not decoration. The `ripemd160` precompile answers the `owner()` selector with 32
bytes whose top 12 bytes are zero, so they read as an address (evidence 1 case 6, verified by
assertion). Without the code check, a VM bound to `0x03` would be "owned" by that address
(assumed: the prototype was not run with the check removed). Nobody holds its key, so the
practical risk is nil, but the rule keeps the property clean.

The helper was also read for memory safety and gas: it writes only scratch memory `0x00-0x1f`, and
a caller who supplies too little gas only makes the `staticcall` fail, which ends in
`InvalidSignature` and harms that caller alone (read, self and reviewer).

Rows 11 to 13 are the residue:

1. Row 11 is the contract's own choice. It lets a stranger give consent, which the
   [core argument](#the-core-argument) shows gives the stranger nothing.
2. Row 12 is the functional gap. Workaround: validate while an EOA owns the contract, then transfer
   ownership. It works once (evidence 2 c12), but a VM cannot be validated twice, so each new VM
   needs an EOA owner again.
3. Row 13: with a shared delegate that has an immutable owner, that owner can validate a VM bound
   to any account that delegates to it. It could be closed by rejecting code that starts with
   `0xef0100`. The account can validate itself anyway.

### 6. Changing code

A validated VM binds an **address**, not code. That is also true today for an EIP-7702 account,
which can change its delegate at will.

1. Redeploy at the same address with other code. EIP-6780 (Cancun) narrowed `SELFDESTRUCT` but
   kept one case: a contract destroyed in the transaction that created it is still removed. So
   this sequence remains possible on the target EVM (`evm_version = osaka`): a constructor
   validates the VM (evidence 3 case 6, verified: validation during construction works, with
   `code.length == 0`), the contract destroys itself in that same transaction, and a later CREATE2
   with the same salt puts other runtime code at the validated address. An address can also be
   validated before it has any code, and filled later. (assumed for the EIP-6780 rule and the
   redeploy: not run here; Phase 2 adds the test. The first draft of this document called the
   pattern dead; the reviewer corrected it.) Under (c) the same end state needs an EIP-7702 account.
   **Consequence: a controller who names an address cannot rely on having read its code.**
2. Upgradeable proxy: whoever can upgrade it controls what the key does. The controller who names a
   proxy as a VM trusts its upgrade admin, as they would trust the holder of an EOA key.

In both cases the remedy is the one that exists for a leaked EOA key: a controller expires the VM.
Verified: after `expireVm`, `isAuthorized` is false for the contract (evidence 1, case 5).

### 7. Ownership over time

1. Under (c), validation reads `owner()` once. After transfer or renounce the VM stays active
   (evidence 2, case 12, verified). A new owner cannot validate again (`VmAlreadyValidated`).
2. Under (a), the contract's own code decides at the time of the call; there is no owner concept in
   the DID contract at all.
3. Who can expire the VM: any EOA authentication key of the DID or of one of its controllers, by
   `expireVm`. The contract's owner cannot, unless they also hold such a key. That is enough, and it
   is the right side: revocation belongs to the DID.

### 8. Who may validate

1. **Only the address side gives consent**: the contract itself under (a), its `owner()` under (c).
   A controller of the DID must not be able to validate alone. That would remove consent, and a
   stranger could then make any contract an active key of the stranger's DID.
2. **Can a stranger put my contract in their DID and get it validated?** They can always name it
   (`createVm` is theirs). Validation needs my contract's consent. Under (c): only if my `owner()`
   returns them. Under (a): only if my contract makes arbitrary calls for arbitrary callers
   (evidence 3, cases 4 and 5, verified). In both cases the result is a key of *their* DID, and
   `isAuthorized` for any DID they do not control stays false (evidence 3, case 5, verified).
3. **One contract as a VM of several DIDs**: allowed and harmless, as for an EOA today (evidence 2,
   case 13, verified). Each call names the DID and VM it acts as.
4. **The validator picks the expiration, and can spoil the VM with it.** Two existing behaviours,
   both verified on unchanged source:
   - A past timestamp (`expiration = 1`): the VM is validated and already dead, and cannot be
     validated again (evidence 1 case 7).
   - A value of `2**88` or more: `uint88(expiration)` truncates (`src/storage/VMStorage.sol` line 135,
     `VMStorageNative.sol:115`). With `2**88` the call succeeds and emits `VmValidated`, but the
     stored expiration is 0: the VM is still pending and can be validated again (evidence 1
     case 8). The event is then untrue.

   Today only the key holder can do this, to its own VM. With contract keys, anyone who can give
   consent for the contract can: under (c) a stranger when `owner()` returns `tx.origin` (row 11 of
   point 5); under (a) a stranger when the contract makes arbitrary calls for anyone (evidence 3
   case 4). They can repeat it on every new VM bound to that contract. It costs the controller a
   VM id each time and gives the stranger nothing else. The remedy is on the contract side: an
   issuer contract validates behind its own access control, with the expiration fixed in its code.
5. **Full variant only**: a VM created with `ethereumAddress = 0` and only a `blockchainAccountId`
   or a public key is active from creation, with no consent step (`src/storage/VMStorage.sol` lines 69 to 75,
   read). So validation protects `isAuthorized`, not the resolved document: a controller can already
   list any account id, including a contract's, in its document. Such a VM can never pass
   `isAuthorized`, because the compared address is zero. No option changes this.

### 9. Existing behaviour

| # | Check | (c) owner call | (a) guard removed |
|---|---|---|---|
| 1 | existing suite, 453 tests | 453 pass | 451 pass; the 2 failures are the tests that assert the old rule |
| 2 | `validateVm` median gas, EOA path | +26 (35,357 to 35,383) | -45 (to 35,312) |
| 3 | `createDid` median gas | +26 | 0 |
| 4 | runtime size, Full / Native | +101 B / +98 B | -8 B / -8 B |
| 5 | EOA reverts (`InvalidSignature`, `VmAlreadyValidated`) and `VmValidated` event | same | same |

All verified (`measurements.txt`; evidence 2 cases 1, 12, 14; evidence 3 case 7). Expiry of a
contract VM by the controller behaves as for an EOA VM (evidence 1 case 5). DID deactivation and
reactivation with a contract VM present were not probed; they do not read the VM's address type
(read, `src/DidAggregate.sol` lines 95 to 152), and Phase 2 adds the test.

### 10. Alternatives

See the next section.

## Alternatives Compared

| # | | (a) remove the guard from `validateVm` | (b) ERC-1271 signature, new function | (c) `owner()` validates (the proposal) |
|---|---|---|---|---|
| 1 | Who consents | the contract, by calling | the contract, by `isValidSignature` | the contract's `owner()` |
| 2 | Change in `src/` | delete one modifier use | new external function, digest with domain separation, `SignatureChecker` call | helper with assembly, one condition in two storage files |
| 3 | Calls foreign code in a write | no | yes | yes |
| 4 | ABI | unchanged | **one function added** | unchanged |
| 5 | Size per manager | -8 B (verified) | larger than (c) (assumed, not built) | +101 B / +98 B (verified) |
| 6 | EOA path gas | -45 (verified) | 0 expected (assumed) | +26 (verified) |
| 7 | Contract owned by a multisig or DAO | works (verified, evidence 3 case 2) | works if the contract implements ERC-1271 | **does not work** (verified) |
| 8 | Needs from the issuer contract | one function that calls `validateVm` | ERC-1271, which also opens the off-chain path for it | ERC-173 `owner()` held by an EOA |
| 9 | Guard count | 7 of 8 | 8 of 8, plus a ninth unguarded write | 8 of 8 |
| 10 | "No write accepts a signature" (`PROJECT.md` section 6) | holds | **broken** | holds |
| 11 | Consent can be given by someone else when | the contract makes arbitrary calls for anyone; a 7702 account's delegate executes calls for a relayer | its `isValidSignature` accepts anything | its `owner()` returns the caller's choice; shared 7702 delegates |
| 12 | Who can then spoil the VM through `expiration` (point 8) | the same parties as row 11 | the signature fixes the expiration (if the digest includes it) | the same parties as row 11 |
| 13 | Existing tests to change | 2 | 0 | 0 |

**What the guard does on `validateVm` today.** `_validateVm` already requires
`msg.sender == vm.ethereumAddress` (`src/storage/VMStorage.sol` line 133, read). A plain EOA can only be
`msg.sender` of a transaction it signed, so for plain EOAs the guard adds nothing on this function.
Its effect is to stop every address that is *not the transaction's signer* from validating itself.
Three kinds of caller are in that set, and (a) admits all three:

1. A deployed contract. This is the goal.
2. A contract inside its own constructor, which has no code yet (evidence 3 case 6, verified).
3. An EIP-7702 account whose delegate executes a call on behalf of a relayer. Today the account's
   key must sign the transaction that validates. Under (a) the delegate's code can validate while
   someone else signs. (assumed: reasoned from the guard, not probed; Phase 2 adds the test.) The
   key chose that delegate, and this matches the limit the guard already documents for the other
   writes, but for `validateVm` it is a change and the NatSpec at `src/DidAggregate.sol` lines 51 to 58 must
   say so. Plain EOAs are unchanged (evidence 3 case 7, verified).

The confused-deputy protection does not depend on the guard here: a contract that a user calls can
only validate a VM bound to *that contract*, never the user's (evidence 3 case 3, verified). The
review looked for other effects of the guard on this function (reentrancy, read-only reentrancy,
front-running, phishing of an EOA) and found none: (a) adds no external call.

**The strongest case against (a)**, from the review: consent becomes "whatever the code at that
address does", and nothing on chain tells the cases apart: constructors, deployers that can swap
code, 7702 delegates, open-call contracts. (c) keeps consent with an `owner()` who signs a direct
transaction. And (a) withdraws a property published in v1.4.0, in a contract that can never be
amended. Against that: (c) has the same kind of residue (rows 11 and 13 of point 5), calls foreign
code, and fails for multisig owners; and no probe or review step found a way to turn wider consent
into power over a DID the caller does not control.

**Recommendation: (a), with two conditions.** Phase 2 ships a reference issuer contract (validation
behind access control, expiration fixed in code) with its tests, and the docs carry the warnings in
[Ranked Findings](#ranked-findings) rows 1 to 3. It removes the one rule that forbids the goal and
adds nothing. (c) keeps
the rule and opens a side door through code we do not control, costs more, and fails for the
institutions most likely to run an issuer contract. (b) is the direction the roadmap sketched; it
breaks rule 2 of the brief (ABI) and the "no signature on a write" property, and it forces every
issuer contract to implement ERC-1271.

The cost of (a) is a statement, not a hole: "all 8 authenticated writes require a direct EOA call"
becomes "the 7 writes that change a DID document require a direct EOA call; `validateVm` requires
the caller to be the VM's own address". The roadmap recorded "writes stay direct-EOA" as the
working assumption "until decided otherwise" (`improvement-roadmap.md:135-146`). Choosing (a)
decides otherwise, for this one function.

## Decisions for the Owner

| # | Decision | Options | Recommended |
|---|---|---|---|
| D1 | Mechanism | A: (a) remove the guard from `validateVm`. B: (c) `owner()` with the five rules. C: stop, build nothing | A |
| D2 | May a contract key hold authentication `0x01`? | A: no limit in DID, controller's choice. B: `validateVm` refuses `0x01` for an address with code | A |
| D3 | Accept that a validated ERC-1271 contract passes `isAuthorizedOffChainWithSigner` | A: accept and document. B: block contract signers in that view | A |
| D4 | Only if D1 = B: reject EIP-7702 delegated accounts on the `owner()` path | A: reject (`0xef0100` prefix). B: allow | A |

**Decided 2026-11-17**: D1 = A, D2 = A, D3 = A. D4 does not apply.

Two more, from the [reactivation fix](#reactivation-fix). **Decided 2026-11-17: D5 = B, D6 = A.** D5 went against the recommendation: the owner keeps the DID's own live key able to reactivate after a controller's deactivation.

| # | Decision | Options | Recommended |
|---|---|---|---|
| D5 | Self-reactivation of a DID that has controllers | A: needs the controller rule, as every other write (the DID's own key cannot undo a controller's deactivation). B: keep the bypass, check key expiry only | A |
| D6 | A deactivated DID with no controller whose keys have all expired can never be reactivated | A: accept and document. B: keep a way back in (which is the behaviour being removed) | A |

D2 option B would add a `revert` that fails the repository's trust-boundary test and would need a
code-length read on the EOA path. D3 option B would undo roadmap idea #1 for every contract.

## Ranked Findings

Merged from the self-pass and the independent review (fresh context, 2026-11-17). The reviewer's
load-bearing claims were re-checked: rows 2, 8 and 12 by a test run, rows 4, 7 and 9 by reading the
cited lines. "Status" says what this revision did.

| # | Severity | Finding | Source | Evidence | Status |
|---|---|---|---|---|---|
| 1 | major | Point 6 said CREATE2 redeploy is dead since EIP-6780. Wrong: the same-transaction case remains, and under (a) a constructor can validate, self-destruct, and the address can later hold other code | reviewer | verified for constructor-time validation (evidence 3 case 6); assumed for EIP-6780 and the redeploy | Point 6 rewritten. Phase 2: test, and a line in the deployment guide |
| 2 | major | Under (a), whoever can make an open-call contract call `validateVm` picks the expiration and can spoil each new VM. The draft listed this for (c) only. `uint88` truncation makes `VmValidated` untrue for values of `2**88` or more | reviewer | verified (evidence 1 cases 7 and 8; evidence 3 case 4) | Point 8 and alternatives row 12 rewritten. Phase 2: reference issuer contract. No on-chain bound proposed: it harms only the address's own VM, so it fails the trust-boundary test; the owner may overrule |
| 3 | major | "The guard's only effect on `validateVm`" was incomplete: it also blocks constructors and 7702 accounts driven by a relayer. For 7702 accounts (a) moves consent from the key's transaction to the delegate's code | reviewer | assumed (reasoned, not probed) | Alternatives section rewritten. Phase 2: test with a real delegation and a relayer; NatSpec |
| 4 | major | The (c) prototype ran 4 of 21 tests on Native, while the draft said "all verified" for both | reviewer | verified (`proto-owner-call-results.txt`) | Point 5 table now marks each row F or F+N |
| 5 | major | (c) cannot validate a contract whose owner is a contract | self | verified (evidence 2 c9) | Stated in the verdict; reason for D1 = A |
| 6 | minor | A DID whose only live `0x01` keys are contracts can no longer write to its own document | self | read (all writes guarded) | Point 2. Phase 2: threat model and SDK note |
| 7 | minor | Case numbers in the point 5 table did not match the test names; one citation in the core argument pointed at a test that does not show the claim | reviewer | verified | Fixed: tests are cited by name |
| 8 | minor | Probe cases 4, 6 and 7 logged values without asserting them | reviewer | verified | Assertions added, suite rerun: 26 of 26 pass |
| 9 | minor | Full variant: a VM without an address is active at creation with no consent, so validation protects `isAuthorized`, not the resolved document | reviewer | read (`VMStorage.sol:69-75`) | Point 8, item 5 |
| 10 | minor | Three wrong line citations | reviewer | verified | Fixed |
| 11 | note | A controller talked into naming an open generic-call contract (a multicall, a router) makes its DID, and every DID it controls, usable by anyone in VClaim and Trust | reviewer | assumed | Phase 2: warning in the threat model here; reported for vclaim and trust |
| 12 | major | Existing behaviour, not caused by this design: self-reactivation accepts an expired or never-validated key and skips the controller rule | reviewer, then self | verified (`probe-reactivation`) | Owner ruled it unintended; fixed in this branch, see [Reactivation Fix](#reactivation-fix) |
| 13 | note | Native variant always resolves a VM as an ECDSA key type, which is not true for a contract | self | read (`W3CResolverNative.sol:21`) | Reported under other repositories; presentation only |
| 14 | note | Nothing found: memory safety and gas handling of the (c) helper; reentrancy, front-running and EOA phishing on `validateVm` under (a) | reviewer | read | none needed |

Kept as is on the reviewer's advice: the structure of the core argument, the alternatives table,
the reasoning for D2 and D3, the five rules for (c), the other-repositories table.

## Reactivation Fix

Found by the review, outside the original scope, and included in this branch by the owner's
decision of 2026-11-17 ("if it is expired no reactivation possible").

**Today (v1.0.2 to v1.7.0).** On the self path (`senderId == targetId`) `reactivateDid` checks only
`_isVmOwner`: the caller's address is in a VM that has the `0x01` bit
(`src/DidAggregate.sol` lines 125 to 130, `src/storage/VMStorage.sol` lines 257 to 266, read). It does not check that
the VM was validated, that it is unexpired, or that the caller passes the controller rule. This was
a documented choice (`docs/analysis/did-lifecycle-flows.md` line 336: "Validates `_isVmOwner` only").
Verified on unchanged source, both variants (`probe-reactivation.t.sol.txt`, and cases 9 and 10 of
the first probe run):

| # | Case | Result today |
|---|---|---|
| 1 | key was validated, then expired by the owner; DID deactivated; that key reactivates | succeeds |
| 2 | key was named but never validated; DID deactivated; that address reactivates | succeeds |
| 3 | DID has a controller; the controller deactivates it; the DID's own key reactivates | succeeds |
| 4 | no controller; DID deactivated; 366 days pass (key lifetime is 365); owner reactivates | succeeds, owner still not authorized |
| 5 | no controller; owner deactivates and reactivates at once | succeeds, owner authorized |

In cases 1 to 3 the caller gains no authentication afterwards, but it undoes a deactivation it had
no right to undo, and the DID's other live keys work again. Case 3 is the heavier one: it bypasses
the controller.

**Fix (as decided, D5 = B).** Both paths require `_isAuthenticated`: a validated, unexpired `0x01`
key of the caller. That closes cases 1, 2 and 4. The controller rule stays where it was, on the
controller path only, so case 3 remains allowed **while the DID's own key is live**: the owner
decided that a DID's own key can always bring it back. The `_isVmOwner` hook has no caller left and
is deleted (9 hooks become 8). No ABI change. On the self path an expired, pending or missing key
now gives `VmAlreadyExpired` (it gave success).

**Accepted residual (D5).** A controller's deactivation is not final while the DID still has a live
authentication key of its own. A controller who wants it final first expires those keys
(`expireVm`), then deactivates. The first proposal (apply `_isControllerFor` on the self path too)
was not taken.

**What it costs (D6).** A DID with no controller that stays deactivated until all its
authentication keys have expired cannot come back. That is consistent with an active DID, which is
equally stuck once its last authentication key expires, but it is a real change for owners who
"park" a DID by deactivating it. The remedy is a controller, which can reactivate.

**Deployed contracts.** v1.7.0 on Sepolia is immutable and keeps the old behaviour. The threat
model must say so.

## Phase 2 Outline

The full task plan is `.temp/plans/2026-11-17-contract-vm-validation-plan.md` (working file, not
tracked). It has ten tasks: baseline, `validateVm`, property tests with mutation proof, the reactivation rule, the issuer integration test, a whole-branch code review, docs, metrics, the final gate, release preparation up to the tag. The outline below is the earlier summary; where they differ, the plan wins (the code review now runs before docs and metrics, so every published number is taken on a frozen tree).


Written for D1 = A; a short note per step says what changes under D1 = B. Detailed plan after
approval.

1. Tests first. Unit, both variants: contract validates itself; wrong caller; second call;
   constructor-time call; constructor validates then self-destructs and the address is redeployed;
   arbitrary-call contract; EIP-7702 account validated through its delegate by a relayer;
   deactivation and reactivation of a DID that holds a contract VM. A reference issuer contract in
   `test/mocks/` (and in the examples repository): validation behind access control, expiration
   fixed in code. Replace, do not delete, the two
   `test_ValidateVm_Should_Revert_When_CalledThroughIntermediary` tests: the intermediary now gets
   `InvalidSignature` for a VM that is not its own.
2. Invariants: (i) a VM becomes validated only in a call whose `msg.sender` is its address;
   (ii) no call from a contract succeeds on the 7 guarded writes; (iii) EOA path unchanged. Each is
   proven able to fail by a mutation run (put the guard back; remove a guard from another write).
3. Integration: a contract with an assertion key passes `isAuthorized(..., 0x02, contract)`, then is
   expired by the DID's EOA key.
4. Names must match what the profiles select: `foundry.toml` default excludes `testFuzz|invariant`,
   the `ci` profile runs them. Run the final gate with `FOUNDRY_PROFILE=ci`.
5. Source: one line in `src/DidAggregate.sol` line 79, plus NatSpec at `:44-58` and on `validateVm` in
   `IDidWriteOps`. (D1 = B: the patch in evidence 2, plus D4.)
6. Docs that state today's rule, found by `git grep` on 2026-11-17: `PROJECT.md:1486`, `:1512` and
   section 6; `docs/analysis/threat-model.md` line 132 and `:153`; `docs/analysis/improvement-roadmap.md` line 130
   and `:149-170`; `docs/analysis/test-catalog.md` lines 363 to 364; `CLAUDE.md` (the `onlyDirectEOA` line);
   `docs/README.md` index. New text: the warnings of findings 1, 2, 6 and 11 in the threat model, and the
   changed consent rule for 7702 accounts (finding 3). `CHANGELOG.md:229-235`, `:334` and `:352` are history: they get a new
   v1.8.0 entry, not an edit.
7. Metrics with the `metrics-update` skill; release with `release-prep`; stop before the tag.
   Tag `v1.7.0` is not touched.

Before the first build in this worktree: `lib/` holds empty submodule folders
(`git submodule status` shows all three uninitialised, verified), so run
`git submodule update --init` first.

## What the Other Repositories Must Change

Neither needs a code change for the feature to work. Not edited from here.

| # | Repository | Change |
|---|---|---|
| 1 | SSIoBC-vclaim | Docs that say the sender is an EOA (SSIoBC-vclaim, file `claim-lifecycle-flows.md` line 42 and lines 201 to 229) describe one case now. Add the issuer-contract flow and an integration test: a contract with an assertion key calls `issueClaim`. Move the DidManager dependency to v1.8.0 when it exists. |
| 2 | SSIoBC-trust | `setTrust` and `removeTrust` become callable by a contract that holds a `0x01` key. Decide if that is wanted and write it down; if not, the rule goes in `TrustManager`. Add a test for the chosen behaviour. |
| 4 | both | Warn in the docs: a DID that names an open generic-call contract as a key can be used by anyone (finding 11). |
| 3 | both | A VM in the Native variant always resolves with type `EcdsaSecp256k1VerificationKey2019` (`src/W3CResolverNative.sol` line 21, read), which is not true for a contract. Presentation only; the SDK or the consumer has to know. In the Full variant the controller sets the type. |

## Not Covered

1. ERC-6492 (wallets not yet deployed). Unchanged: not supported.
2. Letting a contract perform DID writes. The 7 document writes stay direct-EOA under every option.
3. A bound on the `expiration` argument of `validateVm`. Existing behaviour, listed as a finding.

## Decision Log

| Date | Entry |
|---|---|
| 2026-11-17 | Phase 1 written. Three probe suites run (63 tests). Verdict: valid; proposal safe with changes; alternative (a) recommended. |
| 2026-11-17 | Revised after the independent review: 4 major and 4 minor corrections (findings 1 to 4, 7 to 10), probe assertions added. The recommendation holds, now with two conditions. |
| 2026-11-17 | Owner decided D1 = A, D2 = A, D3 = A, and ruled the self-reactivation behaviour unintended: fix in this branch. Reactivation Fix section and decisions D5, D6 added. |
| 2026-11-17 | Phase 2 plan written and reviewed independently: no blocker, 7 major and 6 minor corrections applied to the plan. Visual map drawn. Task 3 waits for D5 and D6. |
| 2026-11-17 | Owner approved the plan and decided D5 = B (self-reactivation needs a live key only; the controller rule is not added to it) and D6 = A. Plan and this section updated. |
| 2026-11-17 | Phase 2 implemented: commits 6e7c566..c4cdccb. Not released. |
