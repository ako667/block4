import { type Address } from "viem";
import { useReadContract } from "wagmi";
import { marketAbi } from "../config";
import { formatAddress } from "../format";
import { formatUsdc6, impliedYesPct } from "../utils/cpmm";
import type { SubgraphMarket } from "../hooks/useSubgraph";

type Props = {
  market: SubgraphMarket;
  selected?: boolean;
  onSelect?: () => void;
};

export function MarketCard({ market, selected, onSelect }: Props) {
  const addr = market.id as Address;

  const { data: reserveYes } = useReadContract({
    address: addr,
    abi: marketAbi,
    functionName: "reserveYes",
  });

  const { data: reserveNo } = useReadContract({
    address: addr,
    abi: marketAbi,
    functionName: "reserveNo",
  });

  const { data: endTimeOnChain } = useReadContract({
    address: addr,
    abi: marketAbi,
    functionName: "endTime",
  });

  const ry = (reserveYes as bigint | undefined) ?? 0n;
  const rn = (reserveNo as bigint | undefined) ?? 0n;
  const yesPct = impliedYesPct(ry, rn);
  const noPct = 100 - yesPct;
  const poolUsdc = ry + rn;
  const tradeCount = Number(market.tradeCount);

  const endTs = Number((endTimeOnChain as bigint | undefined) ?? BigInt(market.endTime));
  const endLabel =
    endTs > 0
      ? new Date(endTs * 1000).toLocaleDateString(undefined, {
          month: "short",
          day: "numeric",
          year: "numeric",
        })
      : "—";

  const stateClass =
    market.state === "Open"
      ? "badge-open"
      : market.state === "Resolved"
        ? "badge-resolved"
        : "badge-other";

  return (
    <article
      className={`market-card${selected ? " market-card--selected" : ""}`}
      onClick={onSelect}
      role={onSelect ? "button" : undefined}
      tabIndex={onSelect ? 0 : undefined}
      onKeyDown={
        onSelect
          ? (e) => {
              if (e.key === "Enter" || e.key === " ") onSelect();
            }
          : undefined
      }
    >
      <div className="market-card__head">
        <span className={`market-badge ${stateClass}`}>{market.state}</span>
        <span className="market-category">{market.category}</span>
      </div>
      <h3 className="market-card__question">{market.question}</h3>

      <div className="odds-block">
        <div className="odds-labels">
          <span className="odds-yes">YES {yesPct.toFixed(1)}%</span>
          <span className="odds-no">NO {noPct.toFixed(1)}%</span>
        </div>
        <div className="odds-bar" aria-hidden>
          <div className="odds-bar__yes" style={{ width: `${yesPct}%` }} />
        </div>
        <p className="odds-caption">CPMM implied odds · live reserves on Sepolia</p>
      </div>

      <ul className="market-stats">
        <li>
          <span className="market-stats__label">Pool liquidity</span>
          <span className="market-stats__value">{formatUsdc6(poolUsdc)} USDC</span>
        </li>
        <li>
          <span className="market-stats__label">Volume (indexed)</span>
          <span className="market-stats__value">{formatUsdc6(BigInt(market.volume))} USDC</span>
        </li>
        <li>
          <span className="market-stats__label">Trades</span>
          <span className="market-stats__value">{tradeCount}</span>
        </li>
        <li>
          <span className="market-stats__label">Ends</span>
          <span className="market-stats__value">{endLabel}</span>
        </li>
      </ul>

      {tradeCount === 0 && (
        <p className="market-hint">
          No trades yet — be the first. Use <strong>Buy YES shares</strong> above (approve USDC, then buy).
        </p>
      )}

      <footer className="market-card__foot">
        <code title={market.id}>{formatAddress(market.id)}</code>
        <a
          href={`https://sepolia.etherscan.io/address/${market.id}`}
          target="_blank"
          rel="noreferrer"
          onClick={(e) => e.stopPropagation()}
        >
          Etherscan ↗
        </a>
      </footer>
    </article>
  );
}
