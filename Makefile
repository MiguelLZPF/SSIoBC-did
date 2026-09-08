NETWORK ?= local
NET     := ./scripts/network.sh

.DEFAULT_GOAL := help
.PHONY: help anvil check deploy smoke deployments build test fmt

help: ## Show this help
	@echo "Usage: make <target> [NETWORK=<name>]   (default NETWORK=$(NETWORK))"
	@echo ""
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  %-14s %s\n", $$1, $$2}'
	@echo ""
	@echo "Profiles:"
	@ls networks/*.env 2>/dev/null | xargs -n1 basename | sed 's/\.env$$/  /' | sed 's/^/  /'

anvil: ## Start a local anvil matching foundry.toml's evm_version
	anvil --hardfork osaka --chain-id 31337

check: ## Pre-flight only: reachability, chain-id assertion, deployer balance
	@$(NET) check $(NETWORK)

deploy: ## Deploy all four contracts and record the ledger
	@$(NET) deploy $(NETWORK)

smoke: ## Create a DID against the deployed contracts and resolve it
	@$(NET) smoke $(NETWORK)

deployments: ## Print the ledger for this network, each entry LIVE or GONE
	@$(NET) deployments $(NETWORK)

build: ## forge build
	forge build

test: ## forge test (hermetic, never touches a network)
	forge test

fmt: ## forge fmt
	forge fmt
