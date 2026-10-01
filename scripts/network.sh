#!/usr/bin/env bash
# Resolve a network profile, validate it, and run forge against it.
#
#   scripts/network.sh check|deploy|smoke|deployments <network>
#
# The only guard that matters here is the chain-id assertion: every other
# failure is cheap and reversible, deploying to the wrong chain is not.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="${NETWORK_PROFILE_DIR:-$ROOT/networks}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '  %-16s %s\n' "$1" "$2"; }

load_profile() {
  local name="$1" file="$PROFILE_DIR/$1.env"
  if [ ! -f "$file" ]; then
    local avail="" f
    for f in "$PROFILE_DIR"/*.env; do
      [ -e "$f" ] && avail="$avail$(basename "$f" .env) "
    done
    die "no profile '$name'. Expected $file. Available: $avail"
  fi
  set -a
  # shellcheck source=/dev/null
  . "$file"
  set +a

  : "${NETWORK_NAME:?profile $name is missing NETWORK_NAME}"
  : "${RPC_URL:?profile $name is missing RPC_URL}"
  : "${CHAIN_ID:?profile $name is missing CHAIN_ID}"

  local signers=0
  [ -n "${PRIVATE_KEY:-}" ] && signers=$((signers + 1))
  [ -n "${ACCOUNT:-}" ]     && signers=$((signers + 1))
  [ -n "${MNEMONIC:-}" ]    && signers=$((signers + 1))
  [ "$signers" -eq 1 ] || die "profile $name must set exactly one of PRIVATE_KEY, ACCOUNT, MNEMONIC (found $signers)"

  FORGE_SIGNER_ARGS=()
  if [ -n "${PRIVATE_KEY:-}" ]; then
    FORGE_SIGNER_ARGS=(--private-key "$PRIVATE_KEY")
  elif [ -n "${ACCOUNT:-}" ]; then
    FORGE_SIGNER_ARGS=(--account "$ACCOUNT")
  else
    FORGE_SIGNER_ARGS=(--mnemonics "$MNEMONIC" --mnemonic-indexes "${MNEMONIC_INDEX:-0}")
  fi

  export NETWORK_NAME RPC_URL CHAIN_ID
  export DEPLOYMENTS_PATH="${DEPLOYMENTS_PATH:-.deployments.json}"
  read -r -a FORGE_EXTRA <<< "${FORGE_EXTRA_ARGS:-}"
}

deployer_address() {
  if [ -n "${PRIVATE_KEY:-}" ]; then
    cast wallet address --private-key "$PRIVATE_KEY"
  elif [ -n "${ACCOUNT:-}" ]; then
    cast wallet address --account "$ACCOUNT"
  else
    cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index "${MNEMONIC_INDEX:-0}"
  fi
}

assert_chain_id() {
  local live
  live="$(cast chain-id --rpc-url "$RPC_URL")" \
    || die "cannot reach $RPC_URL"
  [ "$live" = "$CHAIN_ID" ] \
    || die "chain-id mismatch: profile '$NETWORK_NAME' expects $CHAIN_ID, $RPC_URL answered $live. Refusing to continue."
  printf '%s' "$live"
}

preflight() {
  local live client deployer balance
  live="$(assert_chain_id)"

  # Some nodes reject web3_clientVersion; that must not abort the preflight.
  client="$(cast rpc web3_clientVersion --rpc-url "$RPC_URL" 2>/dev/null | tr -d '"' || true)"
  deployer="$(deployer_address)"
  balance="$(cast balance "$deployer" --rpc-url "$RPC_URL")"

  note "network"  "$NETWORK_NAME"
  note "rpc"      "$RPC_URL"
  note "chain-id" "$live"
  note "client"   "${client:-unknown}"
  note "block"    "$(cast block-number --rpc-url "$RPC_URL")"
  note "deployer" "$deployer"
  note "balance"  "$(cast from-wei "$balance") ETH"

  [ "$balance" = "0" ] && printf '  warning          deployer balance is zero\n'
  return 0
}

cmd_check() { preflight; }

cmd_deploy() {
  preflight

  # Forge writes the ledger during the run. Point it at a staging copy and promote it
  # only when forge exits 0, so a broadcast that fails part-way leaves the real ledger
  # untouched.
  local real stage_dir stage
  case "$DEPLOYMENTS_PATH" in
    /*) real="$DEPLOYMENTS_PATH" ;;
    *)  real="$ROOT/$DEPLOYMENTS_PATH" ;;
  esac
  stage_dir="$ROOT/.temp/deploy-staging"
  stage="$stage_dir/$NETWORK_NAME-ledger.json"
  mkdir -p "$stage_dir"
  if [ -f "$real" ]; then cp "$real" "$stage"; else rm -f "$stage"; fi

  if ( cd "$ROOT" && DEPLOYMENTS_PATH="$stage" forge script script/DeployAll.s.sol:DeployAllScript \
    --sig "run()" \
    --rpc-url "$RPC_URL" \
    "${FORGE_SIGNER_ARGS[@]}" \
    --broadcast \
    ${FORGE_EXTRA[@]+"${FORGE_EXTRA[@]}"} ); then
    [ ! -f "$stage" ] || mv "$stage" "$real"
  else
    die "forge failed; the ledger at $real was left untouched (staging copy: $stage)"
  fi
}

cmd_deployments() {
  assert_chain_id >/dev/null
  local file
  case "$DEPLOYMENTS_PATH" in
    /*) file="$DEPLOYMENTS_PATH" ;;
    *)  file="$ROOT/$DEPLOYMENTS_PATH" ;;
  esac
  [ -f "$file" ] || die "no ledger at $file"
  jq -e --arg c "$CHAIN_ID" 'has($c)' "$file" >/dev/null \
    || die "ledger has no entries for chain $CHAIN_ID"
  printf '%-20s %-44s %s\n' NAME ADDRESS STATUS
  jq -r --arg c "$CHAIN_ID" '.[$c] | to_entries[] | "\(.key) \(.value.address)"' "$file" \
  | while read -r name addr; do
      local code
      code="$(cast code "$addr" --rpc-url "$RPC_URL")" \
        || die "cannot read code at $addr from $RPC_URL; refusing to report a status"
      if [ "$code" = "0x" ]; then
        printf '%-20s %-44s %s\n' "$name" "$addr" "GONE"
      else
        printf '%-20s %-44s %s\n' "$name" "$addr" "LIVE"
      fi
    done
}

cmd_smoke() {
  preflight
  command -v jq >/dev/null || die "jq is required for smoke"

  # keccak256("DidCreated(bytes32,bytes32)") -- src/interfaces/IDidWriteOps.sol:9
  local did_created_topic
  did_created_topic="$(cast keccak 'DidCreated(bytes32,bytes32)')"

  local random id receipts
  random="$(cast keccak "smoke-$(date +%s)-$RANDOM")"

  forge script script/Smoke.s.sol:SmokeScript \
    --sig "createDid(bytes32)" "$random" \
    --rpc-url "$RPC_URL" \
    "${FORGE_SIGNER_ARGS[@]}" \
    --broadcast \
    ${FORGE_EXTRA[@]+"${FORGE_EXTRA[@]}"}

  receipts="$(find "$ROOT/broadcast/Smoke.s.sol/$CHAIN_ID" -maxdepth 1 -name '*-latest.json' 2>/dev/null | head -1)"
  [ -n "$receipts" ] || die "no broadcast receipt under broadcast/Smoke.s.sol/$CHAIN_ID"

  id="$(jq -r --arg t "$did_created_topic" \
    '[.receipts[].logs[] | select(.topics[0] == $t) | .topics[1]] | first // empty' "$receipts")"
  [ -n "$id" ] || die "no DidCreated log in the receipt; the tx may have reverted"

  printf '  did id           %s\n' "$id"

  forge script script/Smoke.s.sol:SmokeScript \
    --sig "verify(bytes32)" "$id" \
    --rpc-url "$RPC_URL"
}

self_test() {
  local tmp fails=0
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  PROFILE_DIR="$tmp"

  check() { if [ "$2" = "pass" ]; then printf 'ok   %s\n' "$1"; else printf 'FAIL %s\n' "$1"; fails=$((fails+1)); fi; }

  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nCHAIN_ID=1\nPRIVATE_KEY=0x1\n' > "$tmp/good.env"
  ( load_profile good ) >/dev/null 2>&1 && check "valid profile loads" pass || check "valid profile loads" fail

  ( load_profile missing ) >/dev/null 2>&1 && check "missing profile rejected" fail || check "missing profile rejected" pass

  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nPRIVATE_KEY=0x1\n' > "$tmp/nochain.env"
  ( load_profile nochain ) >/dev/null 2>&1 && check "missing CHAIN_ID rejected" fail || check "missing CHAIN_ID rejected" pass

  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nCHAIN_ID=1\n' > "$tmp/nosigner.env"
  ( load_profile nosigner ) >/dev/null 2>&1 && check "zero signers rejected" fail || check "zero signers rejected" pass

  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nCHAIN_ID=1\nPRIVATE_KEY=0x1\nACCOUNT=b\n' > "$tmp/two.env"
  ( load_profile two ) >/dev/null 2>&1 && check "two signers rejected" fail || check "two signers rejected" pass

  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nCHAIN_ID=1\nACCOUNT=b\n' > "$tmp/acct.env"
  ( load_profile acct && [ "${FORGE_SIGNER_ARGS[0]}" = "--account" ] ) >/dev/null 2>&1 \
    && check "ACCOUNT maps to --account" pass || check "ACCOUNT maps to --account" fail

  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nCHAIN_ID=1\nMNEMONIC="test test"\nMNEMONIC_INDEX=3\n' > "$tmp/mn.env"
  ( load_profile mn \
    && [ "${FORGE_SIGNER_ARGS[0]}" = "--mnemonics" ] && [ "${FORGE_SIGNER_ARGS[1]}" = "test test" ] \
    && [ "${FORGE_SIGNER_ARGS[2]}" = "--mnemonic-indexes" ] && [ "${FORGE_SIGNER_ARGS[3]}" = "3" ] ) >/dev/null 2>&1 \
    && check "MNEMONIC maps to --mnemonics/--mnemonic-indexes" pass || check "MNEMONIC maps to --mnemonics/--mnemonic-indexes" fail

  # Stub cast: chain-id and the rest answer, web3_clientVersion fails.
  mkdir -p "$tmp/bin1" "$tmp/bin2"
  cat > "$tmp/bin1/cast" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  chain-id) echo 1 ;;
  rpc) exit 1 ;;
  wallet) echo 0x0000000000000000000000000000000000000001 ;;
  balance) echo 1 ;;
  from-wei) echo 1 ;;
  block-number) echo 7 ;;
esac
STUB
  chmod +x "$tmp/bin1/cast"
  # These run the script as a CHILD process. A subshell on the left of ||, && or if has
  # errexit disabled, which would hide exactly the failures under test.
  local out rc
  set +e
  out="$( PATH="$tmp/bin1:$PATH" NETWORK_PROFILE_DIR="$tmp" bash "${BASH_SOURCE[0]}" check good 2>&1 )"; rc=$?
  set -e
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'client.*unknown'; then
    check "preflight survives a failing web3_clientVersion" pass
  else
    check "preflight survives a failing web3_clientVersion" fail
  fi

  # Stub cast: chain-id answers, code fails. deployments must exit non-zero, not print LIVE.
  cat > "$tmp/bin2/cast" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  chain-id) echo 1 ;;
  code) exit 1 ;;
esac
STUB
  chmod +x "$tmp/bin2/cast"
  printf '{"1":{"DidManager":{"address":"0x00000000000000000000000000000000000000aa"}}}\n' > "$tmp/ledger.json"
  printf 'NETWORK_NAME=a\nRPC_URL=http://x\nCHAIN_ID=1\nPRIVATE_KEY=0x1\nDEPLOYMENTS_PATH=%s/ledger.json\n' "$tmp" > "$tmp/led.env"
  set +e
  out="$( PATH="$tmp/bin2:$PATH" NETWORK_PROFILE_DIR="$tmp" bash "${BASH_SOURCE[0]}" deployments led 2>&1 )"; rc=$?
  set -e
  if [ "$rc" -ne 0 ] && ! printf '%s' "$out" | grep -q 'LIVE' && printf '%s' "$out" | grep -q '0x0000000000000000000000000000000000000000aa\|000aa'; then
    check "deployments dies when cast code fails" pass
  else
    check "deployments dies when cast code fails" fail
  fi

  [ "$fails" -eq 0 ] && { printf 'all self-tests passed\n'; return 0; }
  printf '%d self-test failure(s)\n' "$fails"; return 1
}

main() {
  [ "${1:-}" = "--test" ] && { self_test; exit $?; }
  local cmd="${1:?usage: network.sh check|deploy|smoke|deployments <network>}"
  local net="${2:?usage: network.sh $cmd <network>}"
  load_profile "$net"
  case "$cmd" in
    check)       cmd_check ;;
    deploy)      cmd_deploy ;;
    deployments) cmd_deployments ;;
    smoke)       cmd_smoke ;;
    *)           die "unknown command '$cmd'" ;;
  esac
}

main "$@"
