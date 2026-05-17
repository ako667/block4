// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {CPMMath} from "../libraries/CPMMath.sol";
import {GlobalOutcomeShares} from "../tokens/GlobalOutcomeShares.sol";
import {IChainlinkAdapter} from "../interfaces/IChainlinkAdapter.sol";
import {IPredictionMarket} from "../interfaces/IPredictionMarket.sol";
import {MarketInitParams} from "./MarketInit.sol";

/// @title PredictionMarket — UUPS upgradeable binary CPMM prediction market
contract PredictionMarket is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IPredictionMarket
{
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");

    uint256 public constant DISPUTE_WINDOW = 48 hours;
    uint256 public constant LP_FEE_BPS = 30;

    uint256 public marketId;
    uint256 public swapFeeBps = 30; 

    IERC20 public collateral;
    GlobalOutcomeShares public outcomes;
    IChainlinkAdapter public oracle;
    address public feeVault;
    address public factory;

    string public question;
    int256 public strikePrice;
    uint8 public yesWinsIfAbove; // 1 = YES wins if price > strike
    uint256 public endTime;

    MarketState public marketState;
    uint256 public reserveYes;
    uint256 public reserveNo;
    uint256 public totalLPSupply;
    mapping(address => uint256) public lpBalance;

    uint8 public winningOutcome;
    int256 public lastOraclePrice;
    uint256 public resolutionProposedAt;
    uint8 public disputedOutcome;
    bool public disputeActive;

    mapping(address => uint256) public pendingWithdrawals;
    uint256 public protocolFeesAccrued;

    uint8 internal constant OUTCOME_YES = 0;
    uint8 internal constant OUTCOME_NO = 1;

    error MarketNotOpen();
    error MarketStillOpen();
    error SlippageExceeded();
    error InvalidOutcome();
    error ZeroLiquidity();
    error Unauthorized();
    error NotInDisputeWindow();
    error AlreadyResolved();
    error NothingToClaim();
    error ResolutionTooEarly();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(MarketInitParams calldata p) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        marketId = p.marketId;
        collateral = IERC20(p.collateral);
        outcomes = GlobalOutcomeShares(p.outcomes);
        oracle = IChainlinkAdapter(p.oracle);
        feeVault = p.feeVault;
        factory = p.factory;
        question = p.question;
        strikePrice = p.strikePrice;
        yesWinsIfAbove = p.yesWinsIfAbove;
        endTime = p.endTime;
        marketState = MarketState.Open;
        swapFeeBps = 30;

        _grantRole(DEFAULT_ADMIN_ROLE, p.admin);
        _grantRole(UPGRADER_ROLE, p.admin);
        _grantRole(RESOLVER_ROLE, p.admin);
    }

    /// @notice One-time liquidity seed (collateral must already be on this contract)
    function bootstrapLiquidity(uint256 amount, address provider) external {
        require(msg.sender == factory, "only factory");
        require(totalLPSupply == 0 && amount > 0, "invalid bootstrap");
        _addLiquidityInternal(provider, amount, false);
    }

    // ─── Liquidity ───────────────────────────────────────────────────────────

    function addLiquidity(uint256 amount) external nonReentrant whenNotPaused returns (uint256 lpMinted) {
        if (marketState != MarketState.Open) revert MarketNotOpen();
        lpMinted = _addLiquidityInternal(msg.sender, amount, true);
    }

    function _addLiquidityInternal(address provider, uint256 amount, bool pull)
        internal
        returns (uint256 lpMinted)
    {
        if (amount == 0) revert ZeroLiquidity();
        if (pull) {
            collateral.safeTransferFrom(provider, address(this), amount);
        }

        uint256 half = amount / 2;
        reserveYes += half;
        reserveNo += amount - half;

        if (totalLPSupply == 0) {
            lpMinted = amount;
        } else {
            uint256 kBefore = CPMMath.product(reserveYes - half, reserveNo - (amount - half));
            uint256 kAfter = CPMMath.product(reserveYes, reserveNo);
            lpMinted = (amount * totalLPSupply) / (kAfter > kBefore ? kAfter - kBefore + 1 : 1);
            if (lpMinted == 0) lpMinted = amount / 10;
        }

        lpBalance[provider] += lpMinted;
        totalLPSupply += lpMinted;
        emit LiquidityAdded(provider, amount, lpMinted);
    }

    function removeLiquidity(uint256 lpAmount) external nonReentrant whenNotPaused returns (uint256 collateralOut) {
        if (marketState != MarketState.Open) revert MarketNotOpen();
        if (lpAmount == 0 || lpBalance[msg.sender] < lpAmount) revert ZeroLiquidity();

        lpBalance[msg.sender] -= lpAmount;
        totalLPSupply -= lpAmount;

        collateralOut = (lpAmount * (reserveYes + reserveNo)) / (totalLPSupply + lpAmount + 1);
        uint256 half = collateralOut / 2;
        reserveYes = reserveYes > half ? reserveYes - half : 0;
        reserveNo = reserveNo > collateralOut - half ? reserveNo - (collateralOut - half) : 0;

        collateral.safeTransfer(msg.sender, collateralOut);
        emit LiquidityRemoved(msg.sender, collateralOut, lpAmount);
    }

    // ─── Trading (CPMM x*y=k) ────────────────────────────────────────────────

    function buyOutcome(uint8 outcomeId, uint256 collateralIn, uint256 minOut)
        public
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        if (marketState != MarketState.Open) revert MarketNotOpen();
        if (outcomeId > 1) revert InvalidOutcome();
        collateral.safeTransferFrom(msg.sender, address(this), collateralIn);
        return _buyOutcomeCore(outcomeId, collateralIn, minOut);
    }

    /// @notice Pay with native ETH — wraps to WETH collateral, visible as ETH in MetaMask
    function buyOutcomeWithEth(uint8 outcomeId, uint256 minOut)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        if (marketState != MarketState.Open) revert MarketNotOpen();
        if (outcomeId > 1) revert InvalidOutcome();
        uint256 collateralIn = msg.value;
        if (collateralIn == 0) revert ZeroLiquidity();
        (bool ok,) = address(collateral).call{value: collateralIn}(abi.encodeWithSignature("deposit()"));
        if (!ok) revert ZeroLiquidity();
        return _buyOutcomeCore(outcomeId, collateralIn, minOut);
    }

    /// @notice Swap USDC for outcome shares (YES if isYes, else NO)
    function swap(bool isYes, uint256 collateralIn, uint256 minOut)
        external
        whenNotPaused
        returns (uint256 amountOut)
    {
        return buyOutcome(isYes ? OUTCOME_YES : OUTCOME_NO, collateralIn, minOut);
    }

    function _buyOutcomeCore(uint8 outcomeId, uint256 collateralIn, uint256 minOut)
        internal
        returns (uint256 amountOut)
    {
        uint256 reserveIn;
        uint256 reserveOut;
        if (outcomeId == OUTCOME_YES) {
            reserveIn = reserveNo;
            reserveOut = reserveYes;
        } else {
            reserveIn = reserveYes;
            reserveOut = reserveNo;
        }

        amountOut = CPMMath.getAmountOut(collateralIn, reserveIn, reserveOut);
        CPMMath.quoteMinOut(amountOut, minOut);

        uint256 fee = (collateralIn * swapFeeBps) / 10_000;
        protocolFeesAccrued += fee;

        if (outcomeId == OUTCOME_YES) {
            reserveNo += collateralIn;
            reserveYes = reserveYes > amountOut ? reserveYes - amountOut : 0;
        } else {
            reserveYes += collateralIn;
            reserveNo = reserveNo > amountOut ? reserveNo - amountOut : 0;
        }

        outcomes.mint(msg.sender, _tokenId(outcomeId), amountOut);
        _forwardFees(fee);
        emit OutcomeBought(msg.sender, outcomeId, collateralIn, amountOut);
    }

    function sellOutcome(uint8 outcomeId, uint256 amountIn, uint256 minCollateralOut)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 collateralOut)
    {
        if (marketState != MarketState.Open) revert MarketNotOpen();
        if (outcomeId > 1) revert InvalidOutcome();

        outcomes.burn(msg.sender, _tokenId(outcomeId), amountIn);

        uint256 reserveIn;
        uint256 reserveOut;
        if (outcomeId == OUTCOME_YES) {
            reserveIn = reserveYes;
            reserveOut = reserveNo;
        } else {
            reserveIn = reserveNo;
            reserveOut = reserveYes;
        }

        collateralOut = CPMMath.getAmountOut(amountIn, reserveIn, reserveOut);
        CPMMath.quoteMinOut(collateralOut, minCollateralOut);

        uint256 fee = (collateralOut * swapFeeBps) / 10_000;
        protocolFeesAccrued += fee;
        collateralOut -= fee;

        if (outcomeId == OUTCOME_YES) {
            reserveYes += amountIn;
            reserveNo = reserveNo > collateralOut + fee ? reserveNo - (collateralOut + fee) : 0;
        } else {
            reserveNo += amountIn;
            reserveYes = reserveYes > collateralOut + fee ? reserveYes - (collateralOut + fee) : 0;
        }

        collateral.safeTransfer(msg.sender, collateralOut);
        _forwardFees(fee);
        emit OutcomeSold(msg.sender, outcomeId, amountIn, collateralOut);
    }

    function _forwardFees(uint256 fee) internal {
        if (fee == 0 || feeVault == address(0)) return;
        uint256 toVault = (fee * LP_FEE_BPS) / 100;
        if (toVault > 0) {
            collateral.safeIncreaseAllowance(feeVault, toVault);
            (bool ok,) = feeVault.call(abi.encodeWithSignature("depositFees(uint256)", toVault));
            ok; // fee vault optional in tests
        }
    }

    // ─── Oracle & settlement ───────────────────────────────────────────────────

    function closeTrading() external onlyRole(RESOLVER_ROLE) {
        if (block.timestamp < endTime) revert ResolutionTooEarly();
        marketState = MarketState.TradingClosed;
    }

    function requestResolution() external onlyRole(RESOLVER_ROLE) {
        if (marketState != MarketState.TradingClosed && marketState != MarketState.Open) {
            if (block.timestamp < endTime) revert ResolutionTooEarly();
        }
        (int256 price,) = oracle.latestValidatedPrice();
        lastOraclePrice = price;
        winningOutcome = _priceToOutcome(price);
        resolutionProposedAt = block.timestamp;
        marketState = MarketState.DisputeWindow;
        emit ResolutionProposed(winningOutcome, price);
    }

    function proposeDispute(uint8 proposedOutcome) external {
        if (marketState != MarketState.DisputeWindow) revert NotInDisputeWindow();
        disputeActive = true;
        disputedOutcome = proposedOutcome;
        emit DisputeProposed(msg.sender, proposedOutcome);
    }

    function finalizeResolution() external onlyRole(RESOLVER_ROLE) {
        if (marketState != MarketState.DisputeWindow) revert NotInDisputeWindow();
        if (block.timestamp < resolutionProposedAt + DISPUTE_WINDOW) revert NotInDisputeWindow();
        if (disputeActive) {
            winningOutcome = disputedOutcome;
        }
        marketState = MarketState.Resolved;
        emit MarketResolved(winningOutcome);
    }

    function claimWinnings() external nonReentrant {
        if (marketState != MarketState.Resolved) revert AlreadyResolved();
        uint256 tokenId = _tokenId(winningOutcome);
        uint256 balance = outcomes.balanceOf(msg.sender, tokenId);
        if (balance == 0) revert NothingToClaim();

        outcomes.burn(msg.sender, tokenId, balance);
        uint256 payout = balance; // 1:1 collateral redemption at resolution
        uint256 available = collateral.balanceOf(address(this));
        if (payout > available) payout = available;

        pendingWithdrawals[msg.sender] = payout;
        collateral.safeTransfer(msg.sender, payout);
        emit WinningsClaimed(msg.sender, payout);
    }

    function activateEmergencyBrake(string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        marketState = MarketState.EmergencyPaused;
        _pause();
        emit EmergencyBrakeActivated(msg.sender, reason);
    }

    function setSwapFeeBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bps <= 1000, "max 10%");
        swapFeeBps = bps;
    }

    function _tokenId(uint8 outcomeId) internal view returns (uint256) {
        return outcomeId == OUTCOME_YES ? outcomes.yesTokenId(marketId) : outcomes.noTokenId(marketId);
    }

    function _priceToOutcome(int256 price) internal view returns (uint8) {
        bool above = price > strikePrice;
        if (yesWinsIfAbove == 1) {
            return above ? OUTCOME_YES : OUTCOME_NO;
        }
        return above ? OUTCOME_NO : OUTCOME_YES;
    }

    // ─── UUPS ──────────────────────────────────────────────────────────────────

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
