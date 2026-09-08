# Deployment Guide

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Deployment Steps](#deployment-steps)
- [Post-Deployment Verification](#post-deployment-verification)
- [Network Considerations](#network-considerations)
- [Rollback Strategy](#rollback-strategy)

---

## Pre-Deployment Checklist

Before deploying to any network, verify:

### Code Quality
- [ ] All tests pass: `forge test`
- [ ] Coverage > 90%: `forge coverage`
- [ ] No formatting issues: `forge fmt --check`
- [ ] No lint issues: `forge lint`
- [ ] Contract sizes within EIP-170 limit (24KB): `forge build --sizes`

### Environment
- [ ] `networks/<name>.env` exists and is filled in (see [network-configuration.md](network-configuration.md))
- [ ] `make check NETWORK=<name>` passes, confirming chain ID and deployer balance
- [ ] Target network is correct (the chain-ID assertion enforces this, but read the table it prints)
- [ ] Foundry version matches CI: 1.8.1

### Security
- [ ] Code reviewed (blockchain-code-assassin audit recommended)
- [ ] No hardcoded secrets in source code
- [ ] Private key is for the correct deployer account
- [ ] Contract bytecode hash matches expected build output

---

## Deployment Steps

### 1. Build Contracts

```bash
forge build --force
```

Verify build output matches expected bytecode hashes.

### 2. Dry Run (No Broadcast)

```bash
forge script script/DidManager.s.sol:DidManagerScript \
  --sig "deploy(bool,string,bool)" false "DryRun_Test" false
```

This simulates deployment without broadcasting transactions. Verify:
- No compilation errors
- Gas estimates are reasonable
- Contract addresses are deterministic (if using CREATE2)

### 3. Deploy

```bash
make deploy NETWORK=<name>
```

This runs `script/DeployAll.s.sol`, which deploys `DidManager`, `W3CResolver`,
`DidManagerNative` and `W3CResolverNative` in a single broadcast and wires each
resolver to its manager. It refuses to run unless the live chain ID matches the
profile's `CHAIN_ID`.

To deploy one contract on its own, the individual scripts still exist. Note that
the resolver scripts take the manager **first**:

```bash
forge script script/W3CResolver.s.sol:W3CResolverScript \
  --sig "deploy(address,bool,string,bool)" <DIDMANAGER_ADDRESS> true "W3CResolver_Deploy" true \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

### 4. Store Deployment Metadata

When the `store` parameter is `true`, deployment metadata is written to `.deployments.json`:
- Contract addresses
- Bytecode hashes
- Chain ID
- Timestamp
- Deployment tag

---

## Post-Deployment Verification

### Verify Contract Code

Neither Anvil nor the development chains this project deploys to today carry a block
explorer, so explorer verification is a manual step, not part of `make deploy` or any
`networks/<name>.env` profile. If a chain with a real explorer is ever added as a target,
run `forge verify-contract` by hand:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/DidManager.sol:DidManager \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key <EXPLORER_API_KEY>
```

### Test Resolution

After deploying both DidManager and W3CResolver:

1. Create a test DID on the deployed contracts
2. Resolve it via the W3CResolver
3. Verify the W3C DID document structure is correct
4. Verify expiration is in milliseconds
5. Verify authentication relationship works

### Verify Bytecode Hash

```bash
# Compare deployed bytecode with local build
cast code <CONTRACT_ADDRESS> --rpc-url $RPC_URL | keccak256
```

Compare with the hash stored in `.deployments.json`.

---

## Network Considerations

### Gas Prices

| Operation | Gas (approx) | Notes |
|-----------|-------------|-------|
| DidManager deployment | ~2.8M gas | Largest single transaction |
| W3CResolver deployment | ~1.5M gas | Depends on variant |
| DID creation | ~250K gas | Includes default VM |
| VM addition | ~150K gas | Varies by key material size |
| Service update | ~80K gas | Depends on type/endpoint length |

### Network-Specific Notes

`RPC_URL`, `CHAIN_ID` and the signer are never typed on the command line: they
come from the selected `networks/<name>.env` profile. Quirks specific to a
target chain (zero base fee, a rate-limited RPC endpoint, persistent state
across restarts) are documented once, in
[network-configuration.md](network-configuration.md#chain-traits-that-bite),
rather than repeated per chain here.

- **Mainnet**: Use conservative gas prices, verify high-value operations
- **Goerli/Sepolia**: Free testnet ETH, suitable for integration testing
- **Local (Anvil)**: `make anvil` starts one matching `foundry.toml`'s `evm_version`; `networks/local.env` targets it
- **L2 (Optimism, Arbitrum)**: Lower gas costs, verify L2-specific behavior

---

## Rollback Strategy

The SSIoBC-DID system uses an **immutable architecture** (no proxies, no upgradability). This means:

### If a Bug is Found Post-Deployment

1. **Deploy new contracts** with the fix
2. **Update W3CResolver** to point to the new DidManager
3. **Migrate state** if needed (DIDs are on-chain and cannot be moved)
4. **Communicate** the new contract addresses to all consumers

### Migration Considerations

- Existing DIDs on the old contract remain valid but cannot be migrated
- New DIDs should be created on the new contract
- Resolvers can be updated independently of DidManagers
- Consider deploying a registry contract for contract address discovery

### Emergency Procedures

Since there is no pause mechanism:
- Monitor for unusual activity post-deployment
- Have a communication plan for notifying DID holders
- Consider adding a lightweight registry/directory contract for address updates
