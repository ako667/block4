#!/usr/bin/env bash
# Deploy subgraph to The Graph Studio (after Base Sepolia factory deploy).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/prepare-subgraph.sh "${1:-deployments/base-sepolia.env}"

cd subgraph
if [[ ! -d node_modules ]]; then
  npm install
fi
npm run codegen
npm run build

echo ""
echo "=== The Graph Studio ==="
echo "1. Open https://thegraph.com/studio/"
echo "2. Create subgraph (e.g. prediction-market)"
echo "3. Copy Deploy Key"
echo "4. Run:"
echo "   cd subgraph"
echo "   graph auth --studio YOUR_DEPLOY_KEY"
echo "   graph deploy --studio prediction-market"
echo ""
echo "5. After deploy, copy Query URL into frontend/.env:"
echo "   VITE_SUBGRAPH_URL=https://api.studio.thegraph.com/query/<id>/prediction-market/<version>"
echo "6. Restart: cd frontend && npm run dev"
