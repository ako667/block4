#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

RPC="${RPC_URL:-http://127.0.0.1:8545}"
# Anvil account #0 — always funded with 10_000 ETH
ANVIL_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

if ! curl -s -X POST "$RPC" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | grep -q result; then
  echo "Anvil is not running at $RPC"
  echo "Start it in another terminal: anvil"
  exit 1
fi

# Shell PRIVATE_KEY often points to an unfunded account — ignore it for local deploy
unset PRIVATE_KEY

forge script scripts/DeployLocal.s.sol \
  --rpc-url "$RPC" \
  --broadcast \
  --private-key "$ANVIL_KEY"

# Keep Infura key in frontend/.env after local deploy rewrites contract addresses
if [ -f .env ] && grep -q '^INFURA_API_KEY=' .env; then
  KEY=$(grep '^INFURA_API_KEY=' .env | cut -d= -f2-)
  if ! grep -q '^VITE_INFURA_API_KEY=' frontend/.env 2>/dev/null; then
    echo "VITE_INFURA_API_KEY=$KEY" >> frontend/.env
  fi
fi

echo ""
echo "Done. Restart frontend (from prediction-market/):"
echo "  cd frontend && npm run dev"
echo "Open http://localhost:5173 (stop old Vite if port was taken)"
