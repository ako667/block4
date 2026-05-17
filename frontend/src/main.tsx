import React from "react";
import ReactDOM from "react-dom/client";
import { WagmiProvider, createConfig, http } from "wagmi";
import { arbitrumSepolia } from "wagmi/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { injected } from "wagmi/connectors";
import { anvil, baseSepolia, sepolia } from "./chains";
import { ARBITRUM_SEPOLIA_RPC, BASE_SEPOLIA_RPC, SEPOLIA_RPC } from "./config";
import App from "./App";
import "./styles.css";

const config = createConfig({
  chains: [sepolia, baseSepolia, anvil, arbitrumSepolia],
  connectors: [injected()],
  transports: {
    [sepolia.id]: http(SEPOLIA_RPC),
    [baseSepolia.id]: http(BASE_SEPOLIA_RPC),
    [anvil.id]: http("http://127.0.0.1:8545"),
    [arbitrumSepolia.id]: http(ARBITRUM_SEPOLIA_RPC ?? "https://sepolia-rollup.arbitrum.io/rpc"),
  },
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
);
