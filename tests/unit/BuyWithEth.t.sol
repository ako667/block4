// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockWETH} from "../../contracts/mocks/MockWETH.sol";
import {MockV3Aggregator} from "../../contracts/mocks/MockV3Aggregator.sol";
import {ChainlinkAdapter} from "../../contracts/oracle/ChainlinkAdapter.sol";
import {MarketOracle} from "../../contracts/oracle/MarketOracle.sol";
import {LPVault} from "../../contracts/vault/LPVault.sol";
import {GlobalOutcomeShares} from "../../contracts/tokens/GlobalOutcomeShares.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {PredictionMarketFactory} from "../../contracts/core/PredictionMarketFactory.sol";

contract BuyWithEthTest is Test {
    address internal alice = makeAddr("alice");
    MockWETH internal weth;
    PredictionMarket internal market;

    function setUp() public {
        address admin = address(this);
        weth = new MockWETH();
        MockV3Aggregator feed = new MockV3Aggregator(3_500e8, 8);
        ChainlinkAdapter adapter = new ChainlinkAdapter(address(feed), 3600, admin);
        MarketOracle marketOracle = new MarketOracle(address(adapter), admin);
        LPVault vault = new LPVault(weth, admin);
        GlobalOutcomeShares shares = new GlobalOutcomeShares(admin);
        PredictionMarket impl = new PredictionMarket();
        PredictionMarketFactory f = new PredictionMarketFactory(
            address(impl),
            address(shares),
            address(weth),
            address(adapter),
            address(vault),
            admin,
            address(0),
            address(marketOracle)
        );
        shares.grantRole(shares.DEFAULT_ADMIN_ROLE(), address(f));
        marketOracle.grantRole(marketOracle.DEFAULT_ADMIN_ROLE(), address(f));
        vault.grantCollector(address(f));

        uint256 liq = 10 ether;
        weth.deposit{value: liq}();
        weth.approve(address(f), liq);
        (, address m) = f.createMarket("ETH?", "T", 100e8, 1, block.timestamp + 1 days, liq);
        market = PredictionMarket(m);
        vm.deal(alice, 10 ether);
    }

    function test_buyOutcomeWithEth() public {
        vm.prank(alice);
        market.buyOutcomeWithEth{value: 1 ether}(0, 1);
        assertGt(market.reserveNo(), 0);
    }
}
