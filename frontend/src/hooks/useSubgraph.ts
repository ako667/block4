import { useEffect, useState } from "react";
import { SUBGRAPH_URL } from "../config";

export type SubgraphMarket = {
  id: string;
  question: string;
  state: string;
  tradeCount: string;
};

const QUERY = `{
  markets(first: 10, orderBy: createdAt, orderDirection: desc) {
    id
    question
    state
    trades { id }
  }
}`;

export function useSubgraphMarkets() {
  const [markets, setMarkets] = useState<SubgraphMarket[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(SUBGRAPH_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ query: QUERY }),
        });
        const json = await res.json();
        if (!cancelled && json.data?.markets) {
          setMarkets(
            json.data.markets.map((m: { id: string; question: string; state: string; trades: unknown[] }) => ({
              id: m.id,
              question: m.question,
              state: m.state,
              tradeCount: String(m.trades?.length ?? 0),
            })),
          );
        }
      } catch {
        if (!cancelled) setMarkets([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return { markets, loading };
}
