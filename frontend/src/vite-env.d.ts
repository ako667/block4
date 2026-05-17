/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_USDC: string;
  readonly VITE_PMT: string;
  readonly VITE_GOVERNOR: string;
  readonly VITE_FACTORY: string;
  readonly VITE_SAMPLE_MARKET: string;
  readonly VITE_SUBGRAPH_URL: string;
  readonly VITE_INFURA_API_KEY: string;
  readonly VITE_DEFAULT_CHAIN: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
