import { useCallback, useEffect, useState } from "react";
import { SUBGRAPH_URL } from "../config";

export type SubgraphMarket = {
  id: string;
  question: string;
  category: string;
  state: string;
  volume: string;
  endTime: number;
  tradeCount: string;
};

const QUERY = `{
  markets(first: 10, orderBy: createdAt, orderDirection: desc) {
    id
    question
    category
    state
    volume
    endTime
    trades { id }
  }
  protocolStats(id: "global") {
    totalMarkets
    totalTrades
    totalVolume
  }
}`;

type RawMarket = {
  id: string;
  question: string;
  category: string;
  state: string;
  volume: string;
  endTime: string;
  trades: { id: string }[];
};

export function useSubgraphMarkets() {
  const [markets, setMarkets] = useState<SubgraphMarket[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchMarkets = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);
    try {
      const res = await fetch(SUBGRAPH_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query: QUERY }),
      });
      const json = await res.json();
      if (json.data?.markets) {
        setMarkets(
          (json.data.markets as RawMarket[]).map((m) => ({
            id: m.id,
            question: m.question,
            category: m.category || "general",
            state: m.state,
            volume: m.volume ?? "0",
            endTime: Number(m.endTime ?? 0),
            tradeCount: String(m.trades?.length ?? 0),
          })),
        );
      }
    } catch {
      setMarkets([]);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void fetchMarkets(false);
    const t = setInterval(() => void fetchMarkets(true), 30_000);
    return () => clearInterval(t);
  }, [fetchMarkets]);

  return { markets, loading, refreshing, refresh: () => fetchMarkets(true) };
}
