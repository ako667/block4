# Subgraph GraphQL Queries

## 1. List markets

```graphql
{
  markets(first: 20, orderBy: createdAt, orderDirection: desc) {
    id
    question
    state
    reserveYes
    reserveNo
    createdAt
  }
}
```

## 2. Market trades

```graphql
query Trades($market: ID!) {
  trades(where: { market: $market }, orderBy: timestamp, orderDirection: desc) {
    trader
    outcomeId
    amountIn
    amountOut
    isBuy
    timestamp
  }
}
```

## 3. Protocol stats

```graphql
{
  protocolStats(id: "global") {
    totalMarkets
    totalTrades
    totalVolume
  }
}
```

## 4. Recent liquidity events

```graphql
{
  liquidityEvents(first: 10, orderBy: timestamp, orderDirection: desc) {
    market { question }
    provider
    collateral
    isAdd
  }
}
```

## 5. getTopMarkets (plan)

```graphql
{
  markets(first: 5, orderBy: volume, orderDirection: desc) {
    id
    question
    category
    volume
    state
  }
}
```

## 6. getUserHistory (plan)

```graphql
query getUserHistory($user: Bytes!) {
  trades(where: { trader: $user }, orderBy: timestamp, orderDirection: desc) {
    market { question }
    outcomeId
    amountIn
    isBuy
    timestamp
  }
}
```

## 7. Resolutions

```graphql
{
  resolutions(first: 10, orderBy: timestamp, orderDirection: desc) {
    market { id question }
    winningOutcome
    finalized
    timestamp
  }
}
```
