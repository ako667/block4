#!/usr/bin/env bash
# After deploy-ethereum-sepolia.sh: patch frontend/.env contract addresses (keeps VITE_SUBGRAPH_URL etc.)
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${1:-deployments/ethereum-sepolia.env}"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE"; exit 1; }

set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a

[[ -n "${USDC:-}" && -n "${FACTORY:-}" && -n "${MARKET:-}" ]] || {
  echo "Set USDC, FACTORY, MARKET in $ENV_FILE"
  exit 1
}

FE=frontend/.env
touch "$FE"
for key in VITE_USDC VITE_FACTORY VITE_SAMPLE_MARKET VITE_PMT VITE_GOVERNOR VITE_PAY_WITH_ETH VITE_DEFAULT_CHAIN; do
  sed -i '' "/^${key}=/d" "$FE" 2>/dev/null || sed -i "/^${key}=/d" "$FE"
done

{
  echo "VITE_USDC=$USDC"
  echo "VITE_FACTORY=$FACTORY"
  echo "VITE_SAMPLE_MARKET=$MARKET"
  echo "VITE_PMT=${PMT:-}"
  echo "VITE_GOVERNOR=${GOVERNOR:-}"
  echo "VITE_PAY_WITH_ETH=false"
  echo "VITE_DEFAULT_CHAIN=sepolia"
} >> "$FE"

echo "Updated frontend/.env with Sepolia contract addresses from $ENV_FILE"
echo "Restart: cd frontend && npm run dev"
