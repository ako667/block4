#!/usr/bin/env bash
# Ethereum Sepolia deploy (use SepoliaETH from faucets). Needs PRIVATE_KEY in .env OR pass as 1st argument.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Create prediction-market/.env — copy from .env.example"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

PK="${1:-${PRIVATE_KEY:-}}"
if [[ -z "$PK" ]]; then
  echo "PRIVATE_KEY missing."
  echo "  ./scripts/deploy-ethereum-sepolia.sh 0xYOUR_PRIVATE_KEY"
  exit 1
fi

RPC="${SEPOLIA_RPC:-https://ethereum-sepolia.publicnode.com}"

DEPLOYER=$(cast wallet address --private-key "$PK")
echo "Deployer: $DEPLOYER"
echo "RPC: $RPC"
cast chain-id --rpc-url "$RPC"
echo "Balance (need Ethereum Sepolia ETH):"
cast balance "$DEPLOYER" --rpc-url "$RPC" --ether || true

VERIFY_ARGS=()
if [[ "${SKIP_VERIFY:-1}" == "0" && -n "${ETHERSCAN_API_KEY:-}" ]]; then
  VERIFY_ARGS=(--verify)
  echo "Verify: ON (etherscan.io) — set SKIP_VERIFY=0"
else
  echo "Verify: OFF (faster; set SKIP_VERIFY=0 to verify on Etherscan)"
fi

echo ""
echo "IMPORTANT: run only ONE deploy at a time. Stop other ./scripts/deploy-ethereum-sepolia.sh first."
echo ""

FORGE_ARGS=(--rpc-url "$RPC" --broadcast --private-key "$PK" -vvvv)
if ((${#VERIFY_ARGS[@]} > 0)); then
  FORGE_ARGS+=("${VERIFY_ARGS[@]}")
fi
forge script scripts/Deploy.s.sol "${FORGE_ARGS[@]}"

echo ""
echo "=== Next steps (Markets / The Graph) ==="
echo "1. Copy Factory, SampleMarket, USDC from logs above"
echo "2. On https://sepolia.etherscan.io find Factory deploy tx block number"
echo "3. Edit deployments/ethereum-sepolia.env (FACTORY, MARKET, USDC, START_BLOCK)"
echo "4. ./scripts/prepare-subgraph.sh deployments/ethereum-sepolia.env"
echo "5. cd subgraph && npm run build"
echo "6. goldsky subgraph deploy prediction-market-sepolia/1.0.0 --path . --start-block START_BLOCK"
