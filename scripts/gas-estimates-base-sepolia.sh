#!/usr/bin/env bash
# Fill deployments/base-sepolia.env after deploy, then run this script.
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${1:-deployments/base-sepolia.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Create $ENV_FILE with:"
  echo "  FACTORY=0x..."
  echo "  MARKET=0x..."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
source "$ENV_FILE"
set +a

RPC="${BASE_SEPOLIA_RPC_URL:?Set BASE_SEPOLIA_RPC_URL in .env}"
MARKET="${MARKET:?Set MARKET in $ENV_FILE}"
FACTORY="${FACTORY:?Set FACTORY in $ENV_FILE}"

echo "=== Base Sepolia gas estimates (cast estimate) ==="
echo "Factory: $FACTORY"
echo "Market:  $MARKET"
echo ""

estimate() {
  local label="$1"
  shift
  local gas
  gas=$(cast estimate "$@" --rpc-url "$RPC")
  printf "%-22s %s gas\n" "$label" "$gas"
}

estimate "createMarket" "$FACTORY" \
  "createMarket(string,string,int256,uint8,uint256,uint256)" \
  "Gas benchmark market" "bench" 500000000000 1 9999999999 0

FROM="${FROM:-0x3C44CdDd6b9349c716Df4239024A1b9d47DC6b88}"
PK="${PK:-0x5de4111afa1a4b949b5e847c483fb4f7efc1f4d412a3b095a9ca2e62f4d3ee65}"

cast send "$USDC" "approve(address,uint256)" "$FACTORY" 2000000000 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true
cast send "$USDC" "approve(address,uint256)" "$MARKET" 100000000 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true
cast send "$MARKET" "buyOutcome(uint8,uint256,uint256)" 0 1000000 0 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1 || true

estimate "addLiquidity" "$MARKET" "addLiquidity(uint256)" 1000000 --from "$FROM"
estimate "buyOutcome" "$MARKET" "buyOutcome(uint8,uint256,uint256)" 0 1000000 0 --from "$FROM"
estimate "sellOutcome" "$MARKET" "sellOutcome(uint8,uint256,uint256)" 0 500000 0 --from "$FROM"
estimate "requestResolution" "$MARKET" "requestResolution()"
estimate "claimWinnings" "$MARKET" "claimWinnings()"

echo ""
echo "Use these numbers in FINAL_REPORT §10 table (Base Sepolia column)."
