/** Implied YES probability from CPMM pool reserves (display only). */
export function impliedYesPct(reserveYes: bigint, reserveNo: bigint): number {
  const total = reserveYes + reserveNo;
  if (total === 0n) return 50;
  return Number((reserveNo * 10_000n) / total) / 100;
}

export function formatUsdc6(value: bigint): string {
  const whole = value / 1_000_000n;
  const frac = value % 1_000_000n;
  if (frac === 0n) return whole.toLocaleString();
  return `${whole}.${frac.toString().padStart(6, "0").replace(/0+$/, "")}`;
}
