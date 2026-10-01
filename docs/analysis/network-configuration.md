# Network Configuration

How this repository builds, deploys and smoke-tests against any EVM chain: a local
Anvil, a persistent development chain on a LAN, or a public testnet. There is one
mechanism, and every network is an instance of it.

## Table of Contents

- [The Problem](#the-problem)
- [The Model: a Network Is a File](#the-model-a-network-is-a-file)
- [Profile Variables](#profile-variables)
- [What Is Committed and What Is Not](#what-is-committed-and-what-is-not)
- [Foundry's RPC Endpoints Block](#foundrys-rpc-endpoints-block)
- [The Entrypoint](#the-entrypoint)
- [The Pre-Flight Check](#the-pre-flight-check)
- [Deployment Ledger](#deployment-ledger)
- [Smoke Test](#smoke-test)
- [Chain Traits That Bite](#chain-traits-that-bite)
- [Adding a Network](#adding-a-network)
- [What Changed From the Old Setup](#what-changed-from-the-old-setup)

## The Problem

Before this document, deploying anywhere but a fresh local Anvil meant four
`forge script` invocations with a hand-typed `--rpc-url`, a hand-pasted private key,
and the DidManager address copied by hand into the resolver call. Nothing recorded
which chain was targeted, nothing checked that the chain answering was the chain
intended, and `.deployments.json` grew an entry per attempt with no way to ask
"what is deployed on chain N right now".

Three further defects made the existing configuration actively misleading:

1. `script/Configuration.s.sol` declared seven environment variables. Only
   `DEPLOYMENTS_PATH` was ever read. `PORT`, `CHAIN_ID`, `HARDFORK`,
   `ACCOUNT_NUMBER`, `MNEMONIC` and `ANVIL_CONFIG_OUT` were dead, yet `.env.example`
   advertised them as configuration.
2. `getNetwork()` mapped chain IDs to names through a thirty-deep ternary that was
   wrong in several places and had to be edited to learn any new chain.
3. `retrieveDeployment()` could not work: it parsed `"."` of a JSON *array* and
   decoded the result into a single struct.

## The Model: a Network Is a File

There is no "local mode", no "homelab mode" and no "custom mode". A network is a
`networks/<name>.env` file. Local Anvil and any remote chain are the same kind of
thing, so there is one concept to learn and one place to change.

```
  make deploy NETWORK=<name>
        |
        |  1. source networks/<name>.env
        v
  scripts/network.sh
        |  2. require RPC_URL, CHAIN_ID, a signer
        |  3. assert live chain-id == CHAIN_ID      <- refuses to broadcast otherwise
        v
  forge script script/DeployAll.s.sol --rpc-url "$RPC_URL" --broadcast
        |
        v
  .deployments.json   keyed  chainId -> contractName
```

Selecting a network edits no tracked file, and adding a network edits no code. Deploying
does record the new addresses in the tracked `.deployments.json`, on purpose: deployed
addresses are public information, so the ledger stays in version control.

## Profile Variables

| Variable | Required | Meaning |
|---|---|---|
| `NETWORK_NAME` | yes | Label recorded in the ledger and returned by `getNetwork()` |
| `RPC_URL` | yes | HTTP JSON-RPC endpoint |
| `CHAIN_ID` | yes | Expected chain ID, asserted against the live chain before any broadcast |
| `PRIVATE_KEY` | one signer | Raw deployer key |
| `ACCOUNT` | one signer | Foundry keystore account name, preferred over `PRIVATE_KEY` |
| `MNEMONIC` + `MNEMONIC_INDEX` | one signer | Derive the deployer from a mnemonic |
| `DEPLOY_TAG` | no | Label recorded with each ledger entry, read via `vm.envOr` in `DeployAll.s.sol`; defaults to `"DeployAll"` |
| `FORGE_EXTRA_ARGS` | no | Escape hatch appended verbatim, e.g. `--legacy`, `--slow` |

Exactly one signer form must be set. The wrapper fails loudly if zero or more than
one is present, rather than silently picking.

Foundry 1.8.1 spells the mnemonic signer differently depending on which binary
reads it: `forge script` takes `--mnemonics` and `--mnemonic-indexes`, plural,
while `cast wallet address` takes `--mnemonic` and `--mnemonic-index`, singular.
`scripts/network.sh` builds both forms (`FORGE_SIGNER_ARGS` for `forge script`,
the inline flags in `deployer_address()` for `cast`), so a profile author never
sees the mismatch.

`HARDFORK` is deliberately **not** a profile variable. The EVM version is a build
property, fixed at `evm_version = 'osaka'` in `foundry.toml`, and a per-network
override would produce bytecode that does not match the published size and gas
figures in `docs/metrics/`.

## What Is Committed and What Is Not

This repository is public. A network profile can name an internal host, and a
development chain typically has no authentication in front of it, so profiles are
private by default.

| Path | Tracked | Why |
|---|---|---|
| `networks/local.env` | yes | Anvil on `127.0.0.1`, public test mnemonic, nothing to protect |
| `networks/example.env` | yes | Every variable, documented, with placeholder values |
| `networks/*.env` (everything else) | **no**, gitignored | May carry an internal hostname or a real key |
| `.env` | no, already gitignored | Unchanged |

`.env.example` is rewritten to point at `networks/` and to stop advertising the six
variables that were never read.

The file `latest-anvil-config.json` is deleted. It was tracked at the repository
root, held private keys, was referenced by nothing, was stale (it listed the public
junk-mnemonic accounts), and its name did not even match the `ANVIL_CONFIG_OUT`
default it appeared to satisfy.

## Foundry's RPC Endpoints Block

`foundry.toml` declares `[rpc_endpoints]` with two named entries: `local`, a
fixed `http://127.0.0.1:8545`, and `custom`, which reads `${RPC_URL}` from the
process environment that `scripts/network.sh` exports. Either name works with
`forge test --fork-url <name>` or `cast --rpc-url <name>` in place of a literal
URL.

The block has to sit **after the last key of `[profile.default]` and before
`[lint]`**. TOML tables close implicitly at the next `[table]` header, so
opening `[rpc_endpoints]` any earlier, for instance right after `remappings`,
would silently end `[profile.default]` there and orphan every key meant to
follow it, `fs_permissions` included. No error is raised; the keys just stop
belonging to the table a reader expects.

## The Entrypoint

A `Makefile` at the repository root, delegating to `scripts/network.sh`.

| Target | Does |
|---|---|
| `make help` | List targets. Default goal. |
| `make anvil` | Start a local Anvil matching `foundry.toml`'s `evm_version` |
| `make check NETWORK=<n>` | Pre-flight only: resolve, chain ID, client version, deployer balance |
| `make deploy NETWORK=<n>` | Pre-flight, then `DeployAll`, then record the ledger |
| `make smoke NETWORK=<n>` | Create a DID (which creates its default VM), resolve it through the Full-variant `W3CResolver`, assert the document. The Native variant is not smoke-tested |
| `make deployments NETWORK=<n>` | Print the ledger for that chain, each entry marked `LIVE` or `GONE` |

`NETWORK` defaults to `local`, so `make deploy` on a laptop does the obvious thing.

The wrapper is thin on purpose. It resolves a profile, validates it, runs one
pre-flight assertion, and execs `forge`. Everything else is Foundry.

**`make` is the supported entrypoint, not a convenience wrapper around one.**
`script/Configuration.s.sol` reads `NETWORK_NAME` through a Solidity field
initializer, so the value has to be present in the process environment before
`forge script` starts. `scripts/network.sh` exports it as part of `load_profile`.
Invoking `forge script` directly, bypassing `make` and `scripts/network.sh`,
records `networkName` as an empty string in `.deployments.json` instead of
failing loudly. There is nothing to fix here: it is a property of how Foundry
scripts read their environment, not a bug, and it is documented here so the next
person who reaches for `forge script` directly knows why the ledger entry came
out wrong.

## The Pre-Flight Check

Before any broadcast, `scripts/network.sh` calls `cast chain-id` and compares it to
the profile's `CHAIN_ID`. A mismatch aborts.

This is the only guard that earns its keep. Every other failure here is cheap and
reversible; deploying to the wrong chain is neither. It also catches the ordinary
case of a stale profile pointing at a chain that has since been reset or replaced.

`make check` runs the same pre-flight and stops, so the check can be run on its own
before committing to a deploy.

## Deployment Ledger

`.deployments.json` is re-keyed from a flat, append-only array to a two-level map:

```json
{
  "6660": {
    "DidManager": {
      "address": "0x…",
      "bytecodeHash": "0x…",
      "networkName": "homelab",
      "proxyAddress": "0x0000000000000000000000000000000000000000",
      "tag": "DidManager_Test",
      "timestamp": 1761498992
    },
    "W3CResolver": { "…": "…" }
  },
  "31337": { "…": "…" }
}
```

`proxyAddress` is always the zero address: this project uses no proxies, and
the field is recorded rather than omitted so every entry has a fixed shape.

Two reasons. First, a development chain that persists across restarts gets
redeployed often, and an append-only array grows without bound while the reader has
to scan top-down to guess the current address. Second, `retrieveDeployment()`
becomes implementable: `chainId` plus contract name is an exact key.

The two existing chain-6660 entries are migrated into the new shape rather than
discarded. A resettable development chain can go back to block 0 at any time,
which silently invalidates every address recorded for it while the file itself
stays unchanged. This is why `make deployments` re-checks liveness with
`cast code` and prints each entry as `LIVE` or `GONE` rather than trusting the
file. A ledger that cannot be stale is not achievable here; a ledger that tells
you it is stale is.

`getNetwork()` loses its ternary chain and reads `NETWORK_NAME`, falling back to
`chain-<id>`. It is then correct for every chain that exists and needs no edit to
learn a new one.

## Smoke Test

`script/Smoke.s.sol`, run by `make smoke NETWORK=<n>`, exercises the deployed
contracts on a live chain: call `createDid` (which creates the default verification
method), resolve the document through the Full-variant `W3CResolver`, assert the shape.
The Native variant (`DidManagerNative`, `W3CResolverNative`) is deployed but not
smoke-tested.

`forge test` stays hermetic. It never touches a network, so CI is unaffected and
stays reproducible. A live chain is a deployment target, not a test fixture.

## Chain Traits That Bite

These are properties of a target chain, not of this repository, but they are what
actually breaks a first deploy.

**Setting `gasPrice: 0` fails on a zero-base-fee chain.** The client still defaults
the priority fee to 1 wei, and a priority fee above the max fee is rejected:

```
Error: max priority fee per gas (1) cannot exceed max fee per gas (0)
```

The deploy scripts set no gas fields at all, which is the correct behaviour: the
client fills them in and the effective gas price is 1 wei. If a chain ever needs it
forced, set **both** through `FORGE_EXTRA_ARGS="--gas-price 0 --priority-gas-price 0"`,
or use `--legacy`. Never set only one.

**State can persist across restarts.** A development chain that dumps state to disk
reloads it at boot, so restarting is not resetting. Starting over needs an explicit
`anvil_reset`, and on Anvil that method requires an explicit empty parameter array:

```sh
cast rpc anvil_reset --raw '[]' --rpc-url "$RPC_URL"
```

Without `--raw '[]'` it fails with *"Forking not enabled and RPC URL not provided to
start forking"*.

**A reset chain restarts nonces at zero.** Wallets cache nonces per chain ID and
will report a mismatch until their cached activity is cleared.

**Auto-mining chains produce one block per transaction, instantly.** There is no
pending pool to wait on, so a receipt is available on the first poll.

**`forge script`'s default RPC rate limiter misjudges a bare LAN RPC endpoint.**
`make deploy` against a development chain on a LAN hung for 46 to 121 seconds and
then failed with *"failed to retrieve chain ID from fork endpoint"*, while
`make check` and a plain `cast` call against the identical URL returned instantly.
Foundry 1.8.1's `forge script` throttles outgoing requests to 330 compute units
per second by default, a limit tuned for public RPC providers, and it misjudges an
unauthenticated endpoint with no such quota. The fix is
`FORGE_EXTRA_ARGS="--no-rpc-rate-limit"` **in that network's profile**, not in the
Makefile: the limiter is the right default for a public endpoint, so disabling it
globally would be wrong for any profile that targets one. See
[`networks/example.env`](../../networks/example.env) for the exact line.

## Adding a Network

```sh
cp networks/example.env networks/<name>.env
$EDITOR networks/<name>.env          # RPC_URL, CHAIN_ID, NETWORK_NAME, a signer
make check NETWORK=<name>            # confirm it answers and the chain ID matches
make deploy NETWORK=<name>
make smoke  NETWORK=<name>
```

Selecting the network edits no tracked file, and no Solidity is recompiled to teach the
repository about the chain. `make deploy` records the addresses in the tracked
`.deployments.json` on purpose, because deployed addresses are public information.

## What Changed From the Old Setup

| Before | After |
|---|---|
| Four `forge script` calls, address copied by hand | `script/DeployAll.s.sol`, one call |
| `--rpc-url` and key typed per invocation | `networks/<name>.env`, selected by `NETWORK=` |
| Nothing verified the target chain | `cast chain-id` asserted before broadcast |
| Seven env vars declared, one read | Only variables that do something |
| Thirty-deep chain-ID ternary | `NETWORK_NAME`, with a `chain-<id>` fallback |
| `retrieveDeployment()` could not work | Keyed by `chainId` and contract name |
| Append-only ledger array | `chainId -> contractName` map |
| `latest-anvil-config.json` tracked, with keys | Deleted |
| `deployment-guide.md` documented the wrong resolver signature | Corrected to `deploy(IDidManagerFull,bool,string,bool)` |
