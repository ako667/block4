#!/usr/bin/env bash
# Refresh ABIs and patch subgraph.yaml from deployments/base-sepolia.env
set -euo pipefail
cd "$(dirname "$0")/.."

forge build -q
cp out/PredictionMarketFactory.sol/PredictionMarketFactory.json subgraph/abis/
cp out/PredictionMarket.sol/PredictionMarket.json subgraph/abis/

ENV_FILE="${1:-deployments/base-sepolia.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Deploy to Base Sepolia first: ./scripts/deploy-base-sepolia.sh"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a

[[ -n "${FACTORY:-}" ]] || { echo "Set FACTORY=0x... in $ENV_FILE"; exit 1; }
START_BLOCK="${START_BLOCK:-0}"

export FACTORY START_BLOCK
python3 <<'PY'
import os, re
from pathlib import Path

factory = os.environ["FACTORY"].lower()
block = os.environ.get("START_BLOCK", "0")
p = Path("subgraph/subgraph.yaml")
text = p.read_text()
text = re.sub(
    r"(name: PredictionMarketFactory\n    network: [^\n]+\n    source:\n      address: )\"[^\"]+\"",
    rf'\1"{factory}"',
    text,
    count=1,
)
text = re.sub(
    r"(name: PredictionMarketFactory\n    network: [^\n]+\n    source:\n      address: \"[^\"]+\"\n      abi: PredictionMarketFactory\n      startBlock: )\d+",
    rf"\g<1>{block}",
    text,
    count=1,
)
p.write_text(text)
print(f"Updated subgraph.yaml: factory={factory} startBlock={block}")
PY

chmod +x scripts/prepare-subgraph.sh 2>/dev/null || true
echo "Next: cd subgraph && npm install && npm run codegen && npm run build"
