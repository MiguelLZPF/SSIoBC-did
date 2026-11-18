# Key Lifecycle Hardening (v1.9.0 design)

**Status**: decided by the owner on 2026-11-18: D1 = A, D2 = A, D3 = A. All three changes ship in v1.9.0. Not implemented yet; no change in `src/`.
**Date**: 2026-11-18. **Base**: v1.8.0 (tag `v1.8.0`, commit 73240bc).
**Follows**: [contract-vm-validation-design.md](./contract-vm-validation-design.md), section "Limits Found After Release".

## Table of Contents

- [Verdict](#verdict)
- [Context](#context)
- [Decision](#decision)
- [How It Works](#how-it-works)
- [Evidence](#evidence)
- [What Each Change Costs](#what-each-change-costs)
- [Alternatives](#alternatives)
- [Consequences](#consequences)
- [Decisions for the Owner](#decisions-for-the-owner)
- [Ranked Findings](#ranked-findings)
- [Not Covered](#not-covered)
- [Decision Log](#decision-log)

## Verdict

Three small changes were prototyped against the three limits found after v1.8.0. All three pass
their 38 tests on both variants with an ABI identical to v1.8.0 (functions, errors, events), at
+80 B and +89 B per manager together. **Decided: ship all three** (owner, 2026-11-18). The
recommendation was to ship C1 (withdraw a pending key) and C3 (cap the lifetime) and to leave C2
out, because C2 (validate only on an active DID) adds a revert that fails the repository's own rule
for new reverts, costs 2,300 gas on every validation, and removes a recovery route that is
documented today. The owner chose C2 as well: a deactivation must not be undone by a key that was
still pending. C2 is therefore a recorded exception to the rule for new reverts.

## Context

v1.8.0 let a contract validate a verification method (VM) bound to its own address. After the
release three limits were found and verified on its source (see the v1.8.0 design, "Limits Found
After Release"):

| Limit | In one line |
|---|---|
| L1 | the caller of `validateVm` picks the key lifetime with no upper bound |
| L2 | `validateVm` does not read the state of the DID, so a pending key can be validated on a deactivated DID and then reactivate it |
| L3 | a pending key cannot be withdrawn; `expireVm` reverts on it |

None lets anyone act on a DID whose controller never named them. All three weaken the controller's
ability to take a naming back. L1 for a plain EOA key, L2 and L3 are older than v1.8.0; contract
keys widened who can use them.

## Decision

Proposed, one change per limit:

| # | Change | Closes | Status |
|---|---|---|---|
| C1 | `expireVm` also works on a VM that exists but was never validated. It marks it withdrawn, so it can never be validated | L3 | decided |
| C2 | `validateVm` reverts `DidExpired` when the DID that owns the VM is deactivated or lapsed | L2 | decided (against the recommendation) |
| C3 | `validateVm` stores at most `block.timestamp + 365 days` for a key bound to an address; a larger request, or 0, is stored as that value | L1 (narrows it) | decided |

No function, event or error is added, removed or re-typed.

## How It Works

The full diff is `proto-hardening.patch` in the evidence folder: 4 files, about 20 changed lines.

**C1, withdraw a pending key.** `_expireVm` reverts today when the stored expiration is not in the
future, and a pending VM stores 0. The new condition treats "0 and the VM exists" as expirable and
sets the expiration to `block.timestamp` in the prototype. From then on `validateVm` reverts
`VmAlreadyValidated`, because the stored value is no longer 0 (the error name is misleading for a
withdrawn key; the SDK maps it). **Planned refinement from the review**: store 1, not
`block.timestamp`. With `block.timestamp` a key that was never active cannot be told apart from a
validated key that expired at that time, in `getExpiration` and in `resolve` with expired keys
included. A stored 1 reads as "never active". (assumed: reasoned from the two conditions, not yet
prototyped; `validateVm` and a second `expireVm` still revert because 1 is neither 0 nor in the
future. The plan prototypes it first.) Two side effects to state in NatSpec: `expireVm` renews the
DID's own 4-year expiration, as every write does, so a withdrawal does too. A VM id that does not exist still reverts
`VmAlreadyExpired`, as today. Existence is a non-zero `id` in the Full variant and a non-zero
`ethereumAddress` in the Native variant. Who may call it does not change: the same authenticated,
controller-checked path as every `expireVm`.

**C2, validate only on an active DID.** The internal `_validateVm` hook already looks up the DID
hash; it now returns it as a second value. The external `validateVm` checks `_isExpired(didHash)`
and reverts `DidExpired`. The check is in the external function only, because `createDid` calls the
hook before the new DID has an expiration. `createDid` needs no edit.

**C3, cap the lifetime.** In `_validateVm`, a requested expiration of 0 or above
`block.timestamp + DEFAULT_VM_EXPIRATION` (365 days, the existing constant of each variant) is
stored as that value. This is a clamp, not a revert. It also removes the truncation case of
v1.8.0, where a value of `2**88` emitted `VmValidated` and stored 0. A shorter request is stored
as given.

## Evidence

All in `docs/assets/data/key-lifecycle-hardening/`, verified on 2026-11-18 (the prototype tests
and the size build were re-run by the author of this document).

| # | File | What it is |
|---|---|---|
| 1 | `proto-hardening.patch` | the three changes against v1.8.0 source |
| 2 | `proto-hardening.t.sol.txt`, `proto-hardening-results.txt` | 38 tests, 19 per variant, all pass on the patched tree |
| 3 | `measurements.txt` | sizes, gas, ABI comparison, and the existing tests that fail on the patched tree |

Results, the same on both variants:

| # | Case | Observed |
|---|---|---|
| 1 | owner withdraws a pending `0x01` key | succeeds, `VmExpirationUpdated` emitted; the named address then gets `VmAlreadyValidated`; `isAuthorized` false |
| 2 | `expireVm` on an unknown id; on a live key twice; withdraw twice | `VmAlreadyExpired`; success then `VmAlreadyExpired`; `VmAlreadyExpired` the second time |
| 3 | a stranger tries to withdraw | `NotAuthenticatedAsSenderId`, the key stays pending |
| 4 | `validateVm` on a deactivated DID, also after 366 days; on a DID lapsed by time | `DidExpired`; the DID stays as it was and the VM stays pending |
| 5 | `validateVm` on an active DID; `createDid`; a pending key after the owner reactivated the DID | all work |
| 6 | requested `type(uint88).max`, `2**88`, `type(uint256).max`, now + 366 days | stored now + 365 days |
| 7 | requested now + 365 days; now + 30 days | stored unchanged |
| 8 | requested 1 while the test clock is at 1 (a value equal to now, not a past one) | stored 1, as in v1.8.0: validated and already dead. A truly past value is not tested here; the plan adds it |
| 9 | a stranger validates an open-call contract key with the largest value | stored now + 365 days |
| 10 | `ReferenceIssuer` validates itself; validation in a constructor | work as in v1.8.0 |

## What Each Change Costs

| # | | C1 withdraw | C2 active DID | C3 cap |
|---|---|---|---|---|
| 1 | Gas | `expireVm` median 0 (Full), +19 (Native); the median is a revert path, the success path is +39 (reviewer's run: 48,609 to 48,648, Full) | `validateVm` +2,300 on every call, one cold read of the DID expiration | within the +2,300 measurement; not measured alone |
| 2 | New revert | none (one revert is removed) | `validateVm` can revert `DidExpired` | none (clamp) |
| 3 | Behaviour an integrator can notice | `expireVm` on a pending key succeeds | validating on a deactivated or lapsed DID fails | a request above 365 days is shortened without an error |
| 4 | Existing tests that change | none | none | 5: one unit test that expects a 2-year key, and two fuzz tests on each variant that expect the requested value |

Size is +80 B (Full) and +89 B (Native) for all three together (`measurements.txt`); the split per
change was not measured.

The repository's test for a new `revert` (CLAUDE.md, Validation Scope) asks whether a value can let
someone act on a DID they do not control. C1 and C3 add no revert. C2 adds one, and it fails the
test: only an address the controller named can validate, and only a direct-EOA key can then
reactivate (an open-call contract key cannot pass `onlyDirectEOA` on `reactivateDid`). Nobody acts
on a DID they were not named for. With C1 the owner can withdraw pending keys before deactivating,
which is the source-side remedy. So C2 would be a deliberate exception to the rule, paid by every
validation.

## Alternatives

| # | Alternative | Why not proposed |
|---|---|---|
| 1 | Documentation only | the owner chose a code change on 2026-11-18; L3 has no workaround in v1.8.0 |
| 2 | C3 as a revert, not a clamp | needs a new custom error, which changes the ABI, and adds a revert that harms only the caller's own key |
| 3 | C3 with a cap chosen by the controller at `createVm` | the Native VM is one storage slot and `expiration == 0` is the pending marker; a stored cap needs a flag bit that every reader of the expiration would have to mask. Too invasive for the gain |
| 4 | C3 with the DID's own expiration (4 years) as the cap | closes the truncation but leaves a contract key able to outlive the owner's key by years |
| 5 | Reject a past expiration in `validateVm` | a validator can still pick "one second from now"; a bound cannot stop a spoiled key. C1 does not help either, but spoiling harms one key id only |
| 6 | C2 by making `reactivateDid` refuse keys validated after the deactivation | needs a stored validation time per key |

## Consequences

1. **A key bound to an address lives at most 365 days from its validation (C3).** A key holder can
   no longer choose a longer lifetime. Renewal stays what it is today: a new VM id, created by a
   live key of the DID. Not capped: in the Full variant a VM without an address still takes the
   lifetime the controller gives it at `createVm` (it cannot authorize anything), and
   `validateVm` still does not renew the DID's own expiration (if it did, a stranger driving an
   open-call key could extend a DID). The cap reuses the default-lifetime constant of each variant.
   The clamp is silent: `VmValidated` carries no expiration, so an integrator reads the stored
   value with `getExpiration`.
2. **C3 narrows L1, it does not remove it.** An open-call contract key validated by a stranger at
   day 300 still lives until day 665, while the owner's first key ends at day 365. The owner's
   remedy is unchanged: renew your own key before it expires, and with C1 withdraw a pending key
   you no longer want.
3. **With C2, a pending key can no longer revive a DID (decided, D2 = A).** A deactivated DID comes
   back only through a key that is live at that moment, or through a controller. A DID with no
   controller whose authentication keys have all expired cannot come back, pending keys or not,
   which makes the existing `reactivateDid` NatSpec sentence true as written. This removes a
   recovery route that is documented today (SSIoBC-trust threat model T5: a DID "comes back only
   through an authentication key that is still live or still pending"; the v1.8.0 warnings here say
   the same). Decision D6 of v1.8.0 covered expired keys only; D2 = A extends it to pending keys.
   A key named on a DID that is then deactivated can be validated again after the DID is
   reactivated by a live key (prototype case 5).
4. **Docs to update with the code**: NatSpec of `validateVm`, `expireVm` and `reactivateDid`; the
   threat model's "Limits Found After Release" (resolved in v1.9.0, with what remains); the
   lifecycle flows; the test catalog; `CHANGELOG.md`; metrics.
5. **Tests**: the 5 existing tests are rewritten for the cap; the v1.8.0 lifetime probe stays as
   dated evidence of v1.8.0 and is not run; the prototype tests become real tests; the mutation
   proof gains three mutations (remove each change, a named test fails).
6. **Sibling repositories** (not edited from here; read on 2026-11-18). SSIoBC-vclaim v0.10.0
   always validates with 0 and on an active DID, so nothing changes for it. SSIoBC-trust v0.1.1
   pins v1.8.0 behaviour in its integration tests, and these change when trust moves its pin:
   under C3, `test_openCallerKey_outlivesTheKeyThatNamedIt` and
   `test_reactivateDid_longLivedKeyReactivates` (it validates for three years), and
   `test_openCallerKey_stopsWhenTheDidLapses` keeps passing but no longer tests anything; under
   C2 only, the test of reactivation by a key validated after the lapse. Its threat model rows T5
   and T6 ("no upper bound") are rewritten at the same time.
7. **Deployed contracts**: v1.8.0 is not deployed. v1.7.0 on Sepolia is immutable and keeps L1 for
   EOA keys, L2 and L3.

## Decisions for the Owner

| # | Decision | Options | Recommended |
|---|---|---|---|
| D1 (decided: A) | C1, withdraw a pending key (stored as 1, "never active") | A: include. B: leave out | A: no new revert, +39 gas on the success path, and it is the only remedy for L3 |
| D2 (decided: A, against the recommendation) | C2, `validateVm` needs an active DID | A: include, +2,300 gas per validation, a new revert that fails the repository's rule, and the pending-key recovery route is removed. B: leave out; with C1 the owner withdraws pending keys before deactivating | B. Strongest argument for A: an owner who forgets one pending key cannot make a deactivation final |
| D3 (decided: A) | C3, lifetime cap for address-bound keys | A: silent clamp to 365 days, no ABI change. B: revert above 365 days with a new error (an ABI addition; integrators get a signal). C: no cap, clamp only values that do not fit in 88 bits | A. Strongest argument against: the clamp is silent, and it ends multi-year keys, which SSIoBC-trust documents and tests today |

## Ranked Findings

Merged from the self-pass and the independent review (fresh context, 2026-11-18, with its own
probe of 25 tests per variant on the prototype). The reviewer's claims about the sibling tests and
the trust threat model were re-checked by reading the cited lines. The review confirmed with no
finding: the C1 condition on both variants and for a Full VM without an address; that only a
pending address VM can store 0; the same-block race; the placement and revert order of C2; the C3
boundary arithmetic; and every number in `measurements.txt`, including the identical ABI.

| # | Severity | Finding | Source | Evidence | Status |
|---|---|---|---|---|---|
| 1 | major | C2 fails the repository's rule for a new revert and costs 2,300 gas per validation; with C1 the owner has a source-side remedy | reviewer | verified (gas re-run; `reactivateDid` is guarded, so an open-call key cannot reactivate) | Recommendation changed to D2 = B; the owner then decided D2 = A, so C2 ships as a recorded exception to the rule |
| 2 | major | C2 removes a recovery route that is documented today; the draft presented it as covered by D6, which ruled on expired keys only | reviewer | verified (SSIoBC-trust threat model T5; D6 text) | Consequence 3 rewritten; D2 states it |
| 3 | major | The list of sibling tests that change was incomplete, and "both siblings assume yearly renewal" was wrong for SSIoBC-trust | reviewer | verified (trust integration tests and T6) | Consequence 6 and D3 rewritten |
| 4 | minor | A withdrawal that stores `block.timestamp` makes a never-active key look like an expired one | reviewer | read (`W3CResolver.sol`, `W3CResolverNative.sol`) | Store 1; to prototype first in the plan |
| 5 | minor | Withdrawal renews the DID for 4 years, and the named address then gets the misleading `VmAlreadyValidated` | reviewer | verified (reviewer's probe) | Stated in How It Works; NatSpec and SDK mapping in the plan |
| 6 | minor | "Keys live at most 365 days" was too broad | reviewer | verified (Full VM without an address keeps any lifetime) | Consequence 1 reworded |
| 7 | minor | Evidence row 8 called a value equal to now "past" | reviewer | verified | Relabelled; the plan adds a truly past value |
| 8 | minor | `expireVm` gas was quoted from a revert path | reviewer | verified (gas report) | Success path quoted |
| 9 | minor | Test gaps: the invariant handler has no DID state, deactivate or warp action; C1 is not tested on a Full VM without an address or through a controller DID | reviewer | verified | Plan |
| 10 | minor | Silent clamp or revert with a new error was decided without the owner | reviewer | read | Now option B of D3 |
| 11 | note | Two implicit choices: `validateVm` does not renew the DID; the cap reuses the default constant | reviewer | read | Recorded in Consequence 1 |
| 12 | note | C3 narrows L1 but an open-call key can still outlive the owner's key by up to a year | self | verified (arithmetic checked by the reviewer) | Consequence 2 |


## Not Covered

1. A way to extend a live key without a new VM id. Unchanged.
2. A spoiled key (a past or near expiration chosen by the validator). Unchanged, see alternative 5.
3. The visual map and the implementation plan. They follow the decisions.
4. After these changes any live authentication key of a DID can still undo a deactivation, also one made by a controller. That is decision D5 = B of v1.8.0 and is not reopened here.

## Decision Log

| Date | Entry |
|---|---|
| 2026-11-18 | Proposal written from the three limits found after v1.8.0 and a prototype (38 tests, both variants). Waiting for D1 to D3. |
| 2026-11-18 | Revised after the independent review: no blocker, 3 major and 7 minor findings applied. Recommendation on C2 reversed (leave out). Waiting for D1 to D3. |
| 2026-11-18 | Owner decided D1 = A, D2 = A, D3 = A: all three changes ship. D2 went against the recommendation; C2 is a recorded exception to the rule for new reverts, and the pending-key recovery route is removed. Implementation plan follows. |
