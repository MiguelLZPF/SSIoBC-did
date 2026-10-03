# Network Profiles

One file per network. Selected with `make <target> NETWORK=<name>`.

## Table of Contents

- [Adding a Network](#adding-a-network)
- [What Is Tracked](#what-is-tracked)

## Adding a Network

```sh
cp networks/example.env networks/my-network.env
$EDITOR networks/my-network.env
make check NETWORK=my-network
```

Full reference, including every variable and the chain traits that break a
first deploy: [docs/analysis/network-configuration.md](../docs/analysis/network-configuration.md).

## What Is Tracked

`local.env` and `example.env` only. Every other `*.env` here is gitignored,
because a profile may name an internal host or hold a real key, and this
repository is public.
