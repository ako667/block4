export const GET_TOP_MARKETS = `
  query getTopMarkets {
    markets(first: 5, orderBy: volume, orderDirection: desc) {
      id
      question
      category
      state
      volume
      reserveYes
      reserveNo
    }
  }
`;

export const GET_USER_HISTORY = `
  query getUserHistory($user: Bytes!) {
    trades(where: { trader: $user }, orderBy: timestamp, orderDirection: desc) {
      id
      market { question }
      outcomeId
      amountIn
      amountOut
      isBuy
      timestamp
    }
  }
`;
