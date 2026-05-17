#!/usr/bin/env bash
# Gas matrix for FINAL_REPORT §10 — cast estimate on a deployed stack.
# Usage:
#   ./scripts/gas-estimates.sh <RPC_URL> <ENV_FILE>
# Example (Anvil local):
#   ./scripts/gas-estimates.sh http://127.0.0.1:8545 frontend/.deploy-local-state
# Example (Base Sepolia fork or live — after deploy):
#   ./scripts/gas-estimates.sh http://127.0.0.1:8546 deployments/base-sepolia.env
set -euo pipefail
cd "$(dirname "$0")/.."

RPC="${1:?RPC URL required}"
ENV_FILE="${2:?ENV file required (FACTORY, MARKET, USDC or LOCAL_*)}"

set -a
# shellcheck disable=SC1091
[[ -f .env ]] && source .env
source "$ENV_FILE"
set +a

FROM="${FROM:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
PK="${PK:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"

FACTORY="${FACTORY:-${LOCAL_FACTORY:-}}"
MARKET="${MARKET:-${LOCAL_MARKET:-}}"
COLLATERAL="${USDC:-${LOCAL_WETH:-}}"

[[ -n "$FACTORY" && -n "$MARKET" && -n "$COLLATERAL" ]] || {
  echo "Set FACTORY, MARKET, USDC (or LOCAL_FACTORY, LOCAL_MARKET, LOCAL_WETH)"
  exit 1
}

echo "=== Gas estimates (cast estimate) ==="
echo "RPC:     $RPC"
echo "Chain:   $(cast chain-id --rpc-url "$RPC")"
echo "Factory: $FACTORY"
echo "Market:  $MARKET"
echo "Token:   $COLLATERAL"
echo ""

estimate() {
  local label="$1"
  shift
  local gas
  gas=$(cast estimate "$@" --rpc-url "$RPC" 2>&1) || {
    echo "$label: FAILED — $gas"
    return 0
  }
  printf "%-22s %s gas\n" "$label" "$gas"
}

# createMarket: approve collateral then estimate factory call
cast send "$COLLATERAL" "approve(address,uint256)" "$FACTORY" 2000000000 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true

estimate "createMarket" "$FACTORY" \
  "createMarket(string,string,int256,uint8,uint256,uint256)" \
  "Gas benchmark market" "bench" 500000000000 1 9999999999 1000000000 \
  --from "$FROM"

cast send "$COLLATERAL" "approve(address,uint256)" "$MARKET" 10000000000 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true

# Wrap ETH if collateral is WETH (deposit)
cast send "$COLLATERAL" "deposit()" --value 1ether \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true

estimate "addLiquidity" "$MARKET" "addLiquidity(uint256)" 1000000 --from "$FROM"
estimate "buyOutcome" "$MARKET" "buyOutcome(uint8,uint256,uint256)" 0 1000000 0 --from "$FROM"

# sell requires YES balance — buy first (real tx for state)
cast send "$MARKET" "buyOutcome(uint8,uint256,uint256)" 0 1000000 0 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true
estimate "sellOutcome" "$MARKET" "sellOutcome(uint8,uint256,uint256)" 0 500000 0 --from "$FROM"

estimate "requestResolution" "$MARKET" "requestResolution()" --from "$FROM"
estimate "claimWinnings" "$MARKET" "claimWinnings()" --from "$FROM"

echo ""
echo "Screenshot: cast estimate $MARKET \"buyOutcome(uint8,uint256,uint256)\" 0 1000000 0 --rpc-url <your_rpc>"
