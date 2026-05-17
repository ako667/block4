export const ZERO_ADDRESS =
  "0x0000000000000000000000000000000000000000" as const;

export function isConfigured(addr: `0x${string}`): boolean {
  return addr.toLowerCase() !== ZERO_ADDRESS;
}

export const PAY_WITH_ETH = import.meta.env.VITE_PAY_WITH_ETH === "true";

const infuraKey = import.meta.env.VITE_INFURA_API_KEY as string | undefined;

/** Arbitrum Sepolia via Infura (used when not on local Anvil) */
export const ARBITRUM_SEPOLIA_RPC = infuraKey
  ? `https://arbitrum-sepolia.infura.io/v3/${infuraKey}`
  : undefined;

export const contractsReady =
  isConfigured(
    (import.meta.env.VITE_USDC ?? ZERO_ADDRESS) as `0x${string}`,
  ) &&
  isConfigured(
    (import.meta.env.VITE_SAMPLE_MARKET ?? ZERO_ADDRESS) as `0x${string}`,
  );

export const CONTRACTS = {
  usdc: (import.meta.env.VITE_USDC ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  pmt: (import.meta.env.VITE_PMT ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  governor: (import.meta.env.VITE_GOVERNOR ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  factory: (import.meta.env.VITE_FACTORY ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  sampleMarket: (import.meta.env.VITE_SAMPLE_MARKET ??
    "0x0000000000000000000000000000000000000000") as `0x${string}`,
};

export const GOVERNOR_PROPOSAL_ID = BigInt(
  import.meta.env.VITE_GOVERNOR_PROPOSAL_ID ?? "0",
);

/** OpenZeppelin Governor.ProposalState */
export const PROPOSAL_STATE_LABELS = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed",
] as const;

export const SUBGRAPH_URL =
  import.meta.env.VITE_SUBGRAPH_URL ??
  "https://api.studio.thegraph.com/query/placeholder/pmt/version/latest";

export const erc20Abi = [
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "mint",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getVotes",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "delegate",
    inputs: [{ name: "delegatee", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;

export const marketAbi = [
  {
    type: "function",
    name: "buyOutcomeWithEth",
    inputs: [
      { name: "outcomeId", type: "uint8" },
      { name: "minOut", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "buyOutcome",
    inputs: [
      { name: "outcomeId", type: "uint8" },
      { name: "collateralIn", type: "uint256" },
      { name: "minOut", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "reserveYes",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "reserveNo",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
] as const;

export const governorAbi = [
  {
    type: "function",
    name: "castVote",
    inputs: [
      { name: "proposalId", type: "uint256" },
      { name: "support", type: "uint8" },
    ],
    outputs: [{ type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "state",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint8" }],
    stateMutability: "view",
  },
] as const;
