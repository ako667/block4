import { defineChain } from "viem";
import { baseSepolia, sepolia } from "viem/chains";

export { baseSepolia, sepolia };

export const anvil = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: { decimals: 18, name: "Ether", symbol: "ETH" },
  rpcUrls: {
    default: { http: ["http://127.0.0.1:8545"] },
  },
});
