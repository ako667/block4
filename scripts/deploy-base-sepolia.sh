#!/usr/bin/env bash
# Base Sepolia deploy (Part D §10). Needs PRIVATE_KEY in .env OR pass as 1st argument.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Create prediction-market/.env from .env.example"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

PK="${1:-${PRIVATE_KEY:-}}"
if [[ -z "$PK" ]]; then
  echo "PRIVATE_KEY missing."
  echo ""
  echo "Option A — add to .env:"
  echo "  PRIVATE_KEY=0xYOUR_KEY"
  echo ""
  echo "Option B — one-shot (replace key):"
  echo "  ./scripts/deploy-base-sepolia.sh 0xYOUR_PRIVATE_KEY"
  exit 1
fi

[[ -z "${BASE_SEPOLIA_RPC_URL:-}" ]] && { echo "Set BASE_SEPOLIA_RPC_URL in .env"; exit 1; }

DEPLOYER=$(cast wallet address --private-key "$PK")
echo "Deployer: $DEPLOYER"
cast chain-id --rpc-url "$BASE_SEPOLIA_RPC_URL"
echo "Balance (need Base Sepolia ETH):"
cast balance "$DEPLOYER" --rpc-url "$BASE_SEPOLIA_RPC_URL" --ether || true

VERIFY_ARGS=()
VERIFY_KEY="${BASESCAN_API_KEY:-${ETHERSCAN_API_KEY:-}}"
if [[ -n "$VERIFY_KEY" ]]; then
  export BASESCAN_API_KEY="$VERIFY_KEY"
  VERIFY_ARGS=(--verify)
  echo "Verify: ON (using BASESCAN_API_KEY or ETHERSCAN_API_KEY)"
else
  echo "Verify: OFF — OK without API key. Deploy works; verify later on sepolia.basescan.org/verifyContract"
fi

forge script scripts/Deploy.s.sol \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast \
  "${VERIFY_ARGS[@]}" \
  --private-key "$PK" \
  -vvvv

echo ""
echo "Copy from logs above:"
echo "  Factory=0x..."
echo "  SampleMarket=0x..."
echo ""
echo "Then:"
echo "  nano deployments/base-sepolia.env"
echo "  ./scripts/gas-estimates-base-sepolia.sh"
