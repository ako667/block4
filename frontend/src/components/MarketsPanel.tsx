import { MarketCard } from "./MarketCard";
import type { SubgraphMarket } from "../hooks/useSubgraph";

type Props = {
  markets: SubgraphMarket[];
  loading: boolean;
  onRefresh?: () => void;
  refreshing?: boolean;
};

export function MarketsPanel({ markets, loading, onRefresh, refreshing }: Props) {
  return (
    <section className="markets-section">
      <div className="markets-section__header">
        <div>
          <h2>Markets (The Graph)</h2>
          <p className="hint markets-section__sub">
            Indexed on Goldsky · odds bar reads live CPMM reserves from Sepolia
          </p>
        </div>
        {onRefresh && (
          <button type="button" className="btn-ghost" disabled={refreshing} onClick={onRefresh}>
            {refreshing ? "Refreshing…" : "Refresh"}
          </button>
        )}
      </div>

      {loading && (
        <div className="markets-loading">
          <div className="markets-loading__pulse" />
          <p>Loading markets from subgraph…</p>
        </div>
      )}

      {!loading && markets.length === 0 && (
        <p className="markets-empty">No markets indexed yet. Deploy subgraph after testnet deploy.</p>
      )}

      {!loading && markets.length > 0 && (
        <div className="markets-grid">
          {markets.map((m) => (
            <MarketCard key={m.id} market={m} />
          ))}
        </div>
      )}
    </section>
  );
}
