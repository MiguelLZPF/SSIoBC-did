---
name: solidity-review
description: >
  Review Solidity changes in this DID contract repository against the project's own
  threat model, validation trust boundary, and published size and gas budgets, rather
  than against a generic smart-contract checklist. USE WHEN: review this contract,
  review my Solidity changes, security review, audit these contracts, is this change
  safe, check this before I merge, does this need a test, I added a require/revert,
  I changed the auth path, I touched DidAggregate or VMStorage, review the PR, look
  over this diff, is this gas increase acceptable, will this still fit under EIP-170,
  I am about to tag a release and want the contracts checked. Use it even when the
  request only says "review" or "check" and the changed files are under src/ or test/,
  because the repository's rules about what may revert on chain are the part a general
  review reliably gets wrong. DO NOT use for formatting or lint (that is forge fmt and
  forge lint), for updating docs/metrics (that is the metrics-update skill), or for
  reviewing non-Solidity code.
model: sonnet
version: 1.0.0
---

# Solidity Review

Reviews changes to this repository's contracts against the constraints this project has
already decided on. The generic parts of Solidity review are handled elsewhere: `forge lint`
and the CI Slither job cover the standard vulnerability classes, and any capable reviewer
already knows what reentrancy is. What no general reviewer knows is that this project has
a written rule about which reverts are allowed to exist, a published gas table that a
careless change invalidates, and a threat model that has already analysed most of the
attacks worth raising.

## Table of Contents

- [Read these first](#read-these-first)
- [Step 1 - Scope the review](#step-1---scope-the-review)
- [Step 2 - The validation trust boundary](#step-2---the-validation-trust-boundary)
- [Step 3 - Authentication invariants](#step-3---authentication-invariants)
- [Step 4 - Storage and hashing invariants](#step-4---storage-and-hashing-invariants)
- [Step 5 - Budgets: size and gas](#step-5---budgets-size-and-gas)
- [Step 6 - Tests](#step-6---tests)
- [What the toolchain already covers](#what-the-toolchain-already-covers)
- [Report format](#report-format)
- [Traps worth knowing](#traps-worth-knowing)

## Read these first

Two documents in this repository decide most review outcomes. Read them before forming an
opinion, because a finding they already dispose of is noise, and repeating it costs the
reader more than it costs you.

| Document | What it settles |
|---|---|
| `docs/analysis/threat-model.md` | DID ID predictability, front-running and MEV, the four controller-delegation attacks, the confused-deputy class and the limit of the guard under EIP-7702, privacy of on-chain identity data |
| `CLAUDE.md`, "Validation Scope and Trust Boundary" | which checks are allowed to exist on chain at all |

If a finding you are about to raise is already analysed in `threat-model.md` with a stated
risk level, do not re-raise it as new. Say that the change moves the analysis, and where.

## Step 1 - Scope the review

Establish what actually changed before reading anything else. A review of the whole
codebase when three lines moved wastes the reader's attention.

```bash
git diff --stat $(git merge-base HEAD main)..HEAD -- src/ test/ script/
git diff $(git merge-base HEAD main)..HEAD -- src/
```

`src/` is about 4,200 lines across 27 files, so a full sweep is a real cost. For a full
audit rather than a diff review, dispatch subagents by area (the two managers, the two
resolvers, the storage contracts, the types and interfaces) and collect their findings,
so the reading stays out of the main context.

Note which variant is touched. The repository ships two: the full W3C variant
(`DidManager`, `VMStorage`, `W3CResolver`) and the Ethereum-native variant
(`DidManagerNative`, `VMStorageNative`, `W3CResolverNative`), over a shared
`DidAggregate` and `VMHooks`. A change to shared code lands in both, and a change to one
variant usually needs its mirror considered. Asking "does the other variant need this
too" catches more real bugs here than any generic checklist item.

## Step 2 - The validation trust boundary

This is the rule a general reviewer gets wrong, and it is the reason this skill exists.

The project deliberately does not validate format, encoding or presentation on chain.
Character-set validation inside `createDid` was measured at +13,183 gas, +4.7%, on every
DID ever created. The contracts are not upgradeable, so a format rule cannot follow a
spec that moves. And a resolver that reverts because it dislikes stored data is a denial
of service against the DID's own owner.

Apply this test to every `revert`, `require` or new guard in the diff:

> Can a malformed value here let someone act on a DID they do not control, or corrupt
> state that is not theirs?

If **no**, the check does not belong on chain, however tidy it looks. Malformed input that
harms only the caller is acceptable: a DID with a nonsense `methods` exists, works for
`isAuthorized`, and simply has no valid W3C string. That is the caller's problem and the
SDK's job to prevent.

A check that is useful but not security-relevant ships as an `external pure` helper
callable at zero gas through `eth_call`, never as an enforced guard.
`W3CResolverBase.checkMethods(bytes32)` is the reference: it enforces all seven canonical
`methods` rules and nothing in the contract calls it.

So the finding to raise is not only "this is missing a check". It is just as often **"this
check should not be here"**, with the gas cost named. Reviews that only ever add
constraints will push this codebase in the wrong direction.

## Step 3 - Authentication invariants

These hold across the whole repository. A diff that breaks one is a blocker regardless of
how the change is otherwise justified.

1. **Identity is `msg.sender`, everywhere.** `tx.origin` is never an identity. It appears
   only inside the `onlyDirectEOA` equality guard.
2. **Every authenticated write carries `onlyDirectEOA`.** There are eight per variant. A
   new authenticated write without it reopens the confused-deputy class that v1.4.0 closed
   (the modifier is defined near the top of `src/DidAggregate.sol`).
3. **Modifier bodies stay a single call into an internal function.** A modifier body is
   inlined at every use site: logic written directly in one cost +158 bytes per manager
   across ten sites and saved about 22 gas per call. Never put a `revert`, a loop, or a
   storage read directly in a modifier body.
4. **The read path is not the write path.** `isAuthorizedOffChain` and
   `isAuthorizedOffChainWithSigner` verify signatures and are views; ERC-1271 contract
   signers are accepted there and only there. Do not let a write path start accepting
   contract signatures without a deliberate decision, because `onlyDirectEOA` is what
   keeps intermediaries out.
5. **Expired or deactivated verification methods never authenticate.** Check that any new
   lookup path goes through the expiration test rather than around it.

## Step 4 - Storage and hashing invariants

6. Hash-based indexing goes through `HashUtils.calculateIdHash` and
   `calculatePositionHash`. A second, ad hoc `keccak256` of the same inputs is a collision
   risk and a maintenance trap.
7. Custom errors only. No `require` with a string anywhere in `src/`; error declarations
   live in `src/types/`.
8. `EnumerableSet` is the collection type for VMs and services. A parallel array that
   shadows a set will drift.
9. The native variant packs a verification method into one slot: address 20 bytes,
   relationships 1 byte, expiration 11 bytes, with an overflow mapping for
   `publicKeyMultibase`. Any new field must state which of those bytes it takes, or it
   silently costs a second slot.
10. Relationship bitmask order is fixed: `0x01` authentication, `0x02` assertion, `0x04`
    keyAgreement, `0x08` capabilityInvocation, `0x10` capabilityDelegation. The resolver
    arrays use the same order.

## Step 5 - Budgets: size and gas

Both are published artifacts, so a regression is not only a cost, it contradicts a
document.

**Size.** The EIP-170 runtime limit is 24,576 bytes and CI validates it
(the "Validate EIP-170 size limits" step in `.github/workflows/ci.yml`). Headroom is comfortable but not unlimited, and the
optimizer is tuned for deployment size (`optimizer_runs = 200`), so a change that trades
size for a little gas is usually the wrong trade here.

```bash
forge build --sizes
```

**Gas.** Compare against the current numbers in `docs/metrics/`, not against intuition.

```bash
forge test --gas-report --no-match-path "test/{stress,performance}/*"
```

Flag any headline operation that moves by 1% or more: `createDid`, `createVm`, `resolve`,
`isAuthorized`, `createService`. If the change is intended and justified, say so and note
that `docs/metrics/` needs the new row, which is the `metrics-update` skill's job, not
this one's.

## Step 6 - Tests

11. A new authenticated write needs a test that it reverts with `DirectEOACallRequired()`
    when called through a contract. `test/unit/DirectEOAGuard.unit.t.sol` holds the mocks.
12. Pranks must be two-argument, `vm.startPrank(user, user)`. A single-argument prank
    leaves `tx.origin` as the default sender and every guarded call reverts, which reads
    as a broken contract rather than a broken test.
13. A test that cannot fail is not a test. If a suite would pass against the code as it
    was before the fix, say so; that has happened here before, in an invariant handler
    that created its DID twice and left every invariant trivially true.
14. Coverage is gated at 90% and currently sits far above it. A change that drops a
    contract below its previous coverage deserves a note even when the gate still passes.

## What the toolchain already covers

Do not spend the reader's attention on these. They run automatically and they are better
at it than a prose review.

| Concern | Covered by |
|---|---|
| Formatting | `forge fmt --check`, `quality` job |
| Lint | `forge lint`, `quality` job |
| Standard vulnerability classes | Slither, `security` job |
| Contract size limit | `build` job, EIP-170 validation |
| Gas delta on a pull request | `gas-diff` job |
| Coverage threshold | `coverage` job |
| Deep property tests | `thorough` job on push to main |

## Report format

Lead with the verdict, then the findings, ordered by severity. Number every finding so the
reader can reply "fix 2 and 4".

```
VERDICT  <blocker | changes needed | ship it>, one line of why

1  BLOCKER   <one-line claim>
   file.sol:42
   Why it matters: <the concrete failure, with inputs or state>
   Fix: <what to change>

2  MEDIUM    ...
```

Severity means: **blocker** if it lets someone act on a DID they do not control, corrupts
state, or breaks a published number; **medium** if it costs gas or size, or leaves a real
case untested; **low** for everything else. Skip a severity band entirely rather than
padding it.

State what you actually checked. A claim that a change is safe is worth nothing without the
file and line, or the command and its output, that backs it. If you did not run the gas
report, do not report a gas conclusion.

Close with what is genuinely well done, but only if it is genuinely well done and specific.
Generic praise trains the reader to skip the section.

## Traps worth knowing

- **The two variants drift.** A fix applied to `DidManager` and not `DidManagerNative` is
  the most common real defect in this codebase's history. Always ask about the mirror.
- **A resolver change is a read-path change**, so its whole size cost lands in the two
  resolvers, not the managers. That is why v1.5.0's DID-string fix shows as roughly +998
  bytes on the resolvers and +790 on the managers.
- **The default local profile skips fuzz and invariant tests** (`no_match_test` in
  `foundry.toml`). A review that concludes "the tests pass" after a bare `forge test` has
  not run the property tests. Use `FOUNDRY_PROFILE=ci`.
- **`checkMethods` is deliberately uncalled.** Finding it unreferenced and proposing to
  wire it into `createDid` is the single most likely wrong recommendation for this
  repository. Read Step 2 again before suggesting it.
- **The contracts are immutable.** There is no upgrade path, so "we can fix it later" is
  not available and a design objection has to be raised before the tag, not after.
