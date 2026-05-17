import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { MarketCreated as MarketCreatedEvent } from "../generated/PredictionMarketFactory/PredictionMarketFactory";
import {
  OutcomeBought,
  OutcomeSold,
  LiquidityAdded,
  LiquidityRemoved,
  MarketResolved,
} from "../generated/templates/PredictionMarket/PredictionMarket";
import { Market, Trade, LiquidityPosition, Resolution, ProtocolStats } from "../generated/schema";
import { PredictionMarket as MarketTemplate } from "../generated/templates";

export function handleMarketCreated(event: MarketCreatedEvent): void {
  let id = event.params.market.toHexString();
  let market = new Market(id);
  market.marketId = event.params.marketId;
  market.question = event.params.question;
  market.category = event.params.category;
  market.strikePrice = BigInt.fromI32(0);
  market.endTime = event.block.timestamp;
  market.reserveYes = BigInt.fromI32(0);
  market.reserveNo = BigInt.fromI32(0);
  market.state = "Open";
  market.volume = BigInt.fromI32(0);
  market.createdAt = event.block.timestamp;
  market.creator = event.transaction.from;
  market.save();

  MarketTemplate.create(event.params.market);

  let stats = ProtocolStats.load("global");
  if (stats == null) {
    stats = new ProtocolStats("global");
    stats.totalMarkets = BigInt.fromI32(0);
    stats.totalTrades = BigInt.fromI32(0);
    stats.totalVolume = BigInt.fromI32(0);
  }
  stats.totalMarkets = stats.totalMarkets.plus(BigInt.fromI32(1));
  stats.save();
}

export function handleOutcomeBought(event: OutcomeBought): void {
  let trade = new Trade(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  trade.market = event.address.toHexString();
  trade.trader = event.params.trader;
  trade.outcomeId = event.params.outcomeId;
  trade.amountIn = event.params.amountIn;
  trade.amountOut = event.params.amountOut;
  trade.isBuy = true;
  trade.timestamp = event.block.timestamp;
  trade.txHash = event.transaction.hash;
  trade.save();
  _bumpVolume(event.address.toHexString(), event.params.amountIn);
}

export function handleOutcomeSold(event: OutcomeSold): void {
  let trade = new Trade(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  trade.market = event.address.toHexString();
  trade.trader = event.params.trader;
  trade.outcomeId = event.params.outcomeId;
  trade.amountIn = event.params.amountIn;
  trade.amountOut = event.params.amountOut;
  trade.isBuy = false;
  trade.timestamp = event.block.timestamp;
  trade.txHash = event.transaction.hash;
  trade.save();
  _bumpVolume(event.address.toHexString(), event.params.amountOut);
}

function _bumpVolume(marketId: string, amount: BigInt): void {
  let market = Market.load(marketId);
  if (market != null) {
    market.volume = market.volume.plus(amount);
    market.save();
  }

  let stats = ProtocolStats.load("global");
  if (stats != null) {
    stats.totalTrades = stats.totalTrades.plus(BigInt.fromI32(1));
    stats.totalVolume = stats.totalVolume.plus(amount);
    stats.save();
  }
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let e = new LiquidityPosition(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  e.market = event.address.toHexString();
  e.provider = event.params.provider;
  e.collateral = event.params.collateral;
  e.lpTokens = event.params.lpMinted;
  e.isAdd = true;
  e.timestamp = event.block.timestamp;
  e.save();
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  let e = new LiquidityPosition(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  e.market = event.address.toHexString();
  e.provider = event.params.provider;
  e.collateral = event.params.collateral;
  e.lpTokens = event.params.lpBurned;
  e.isAdd = false;
  e.timestamp = event.block.timestamp;
  e.save();
}

export function handleMarketResolved(event: MarketResolved): void {
  let r = new Resolution(event.address.toHexString());
  r.market = event.address.toHexString();
  r.winningOutcome = event.params.winningOutcome;
  r.oraclePrice = BigInt.fromI32(0);
  r.finalized = true;
  r.timestamp = event.block.timestamp;
  r.save();

  let market = Market.load(event.address.toHexString());
  if (market != null) {
    market.state = "Resolved";
    market.winningOutcome = event.params.winningOutcome;
    market.save();
  }
}
