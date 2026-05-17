// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PredictionMarket} from "./PredictionMarket.sol";
import {MarketInitParams} from "./MarketInit.sol";
import {GlobalOutcomeShares} from "../tokens/GlobalOutcomeShares.sol";
import {MarketProxy} from "../proxy/MarketProxy.sol";
import {MarketOracle} from "../oracle/MarketOracle.sol";

/// @title PredictionMarketFactory — CREATE + CREATE2 + global ERC-1155
contract PredictionMarketFactory is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant MARKET_CREATOR_ROLE = keccak256("MARKET_CREATOR_ROLE");

    PredictionMarket public immutable implementation;
    GlobalOutcomeShares public immutable outcomeShares;
    address public collateral;
    address public oracle;
    address public feeVault;
    address public timelock;
    MarketOracle public marketOracle;

    uint256 public nextMarketId = 1;
    address[] public allMarkets;
    mapping(bytes32 => address) public marketBySalt;
    mapping(uint256 => address) public marketById;

    event MarketCreated(
        uint256 indexed marketId, address indexed market, bytes32 salt, string question, string category
    );

    constructor(
        address implementation_,
        address outcomeShares_,
        address collateral_,
        address oracle_,
        address feeVault_,
        address admin,
        address timelock_,
        address marketOracle_
    ) {
        implementation = PredictionMarket(implementation_);
        outcomeShares = GlobalOutcomeShares(outcomeShares_);
        collateral = collateral_;
        oracle = oracle_;
        feeVault = feeVault_;
        timelock = timelock_;
        if (marketOracle_ != address(0)) {
            marketOracle = MarketOracle(marketOracle_);
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKET_CREATOR_ROLE, admin);
        if (timelock_ != address(0)) {
            _grantRole(MARKET_CREATOR_ROLE, timelock_);
            _grantRole(DEFAULT_ADMIN_ROLE, timelock_);
        }
    }

    function createMarket(
        string calldata question,
        string calldata category,
        int256 strikePrice,
        uint8 yesWinsIfAbove,
        uint256 endTime,
        uint256 initialLiquidity
    ) external onlyRole(MARKET_CREATOR_ROLE) returns (uint256 marketId, address market) {
        (marketId, market) = _deployMarket(question, category, strikePrice, yesWinsIfAbove, endTime, initialLiquidity, bytes32(0), false);
    }

    function createMarketDeterministic(
        string calldata question,
        string calldata category,
        int256 strikePrice,
        uint8 yesWinsIfAbove,
        uint256 endTime,
        uint256 initialLiquidity,
        bytes32 salt
    ) external onlyRole(MARKET_CREATOR_ROLE) returns (uint256 marketId, address market) {
        (marketId, market) = _deployMarket(question, category, strikePrice, yesWinsIfAbove, endTime, initialLiquidity, salt, true);
    }

    function predictMarketAddress(bytes32 salt, bytes memory initData) external view returns (address) {
        bytes memory bytecode =
            abi.encodePacked(type(MarketProxy).creationCode, abi.encode(address(implementation), initData));
        return Create2.computeAddress(salt, keccak256(bytecode), address(this));
    }

    function _deployMarket(
        string calldata question,
        string calldata category,
        int256 strikePrice,
        uint8 yesWinsIfAbove,
        uint256 endTime,
        uint256 initialLiquidity,
        bytes32 salt,
        bool useCreate2
    ) internal returns (uint256 id, address market) {
        id = nextMarketId++;
        MarketInitParams memory params = MarketInitParams({
            marketId: id,
            collateral: collateral,
            outcomes: address(outcomeShares),
            oracle: oracle,
            feeVault: feeVault,
            factory: address(this),
            admin: msg.sender,
            question: question,
            strikePrice: strikePrice,
            yesWinsIfAbove: yesWinsIfAbove,
            endTime: endTime
        });
        bytes memory initData = abi.encodeCall(PredictionMarket.initialize, (params));

        if (useCreate2) {
            bytes memory bytecode =
                abi.encodePacked(type(MarketProxy).creationCode, abi.encode(address(implementation), initData));
            market = Create2.deploy(0, salt, bytecode);
            marketBySalt[salt] = market;
        } else {
            market = address(new MarketProxy(address(implementation), initData));
        }

        outcomeShares.grantMarketEngine(market);
        marketById[id] = market;
        allMarkets.push(market);

        if (address(marketOracle) != address(0)) {
            marketOracle.registerMarket(id, market);
        }

        if (initialLiquidity > 0) {
            IERC20(collateral).safeTransferFrom(msg.sender, market, initialLiquidity);
            PredictionMarket(market).bootstrapLiquidity(initialLiquidity, msg.sender);
        }

        emit MarketCreated(id, market, salt, question, category);
    }

    function marketCount() external view returns (uint256) {
        return allMarkets.length;
    }
}
