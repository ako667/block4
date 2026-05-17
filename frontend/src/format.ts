/** Trim long wei amounts for UI (full value in title). */
export function formatEthShort(wei: bigint, maxDecimals = 4): string {
  const s = formatDecimalFromWei(wei, 18, maxDecimals);
  return s === "" ? "0" : `${s} ETH`;
}

export function formatTokenShort(amount: bigint, decimals: number, symbol: string, maxDecimals = 2): string {
  const s = formatDecimalFromWei(amount, decimals, maxDecimals);
  return s === "" ? `0 ${symbol}` : `${s} ${symbol}`;
}

function formatDecimalFromWei(value: bigint, tokenDecimals: number, maxDecimals: number): string {
  const negative = value < 0n;
  const abs = negative ? -value : value;
  const base = 10n ** BigInt(tokenDecimals);
  const whole = abs / base;
  let frac = abs % base;
  let fracStr = frac.toString().padStart(tokenDecimals, "0");
  if (maxDecimals < tokenDecimals) {
    fracStr = fracStr.slice(0, maxDecimals);
  }
  fracStr = fracStr.replace(/0+$/, "");
  const out = fracStr.length > 0 ? `${whole}.${fracStr}` : whole.toString();
  return negative ? `-${out}` : out;
}

/** OpenZeppelin Governor proposal id is a hash — show short form in UI. */
export function formatProposalId(id: bigint): string {
  const full = id.toString();
  if (full.length <= 16) return full;
  return `${full.slice(0, 8)}…${full.slice(-6)}`;
}

export function formatAddress(addr: string, head = 6, tail = 4): string {
  if (addr.length < head + tail + 2) return addr;
  return `${addr.slice(0, head + 2)}…${addr.slice(-tail)}`;
}
