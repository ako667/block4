// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkAdapter} from "../../contracts/oracle/ChainlinkAdapter.sol";

/// @dev Fork tests against Ethereum Sepolia ETH/USD feed
contract ChainlinkForkTest is Test {
    address constant ETH_USD_SEPOLIA = 0x694aa1769357219DEA21D23E94fCe2A7CFA3EBD5;

    function test_Fork_ETH_USD_Feed() public {
        string memory rpc = vm.envOr("SEPOLIA_RPC", string("https://rpc.sepolia.org"));
        if (block.chainid != 11155111) {
            try vm.createSelectFork(rpc) {} catch {
                vm.skip(true);
                return;
            }
        }
        ChainlinkAdapter adapter = new ChainlinkAdapter(ETH_USD_SEPOLIA, 3600, address(this));
        (int256 price,) = adapter.latestValidatedPrice();
        assertGt(price, 0);
    }

    function test_Fork_StalenessCheck() public {
        string memory rpc = vm.envOr("SEPOLIA_RPC", string("https://rpc.sepolia.org"));
        try vm.createSelectFork(rpc) {} catch {
            vm.skip(true);
            return;
        }
        ChainlinkAdapter adapter = new ChainlinkAdapter(ETH_USD_SEPOLIA, 1, address(this));
        vm.expectRevert();
        adapter.latestValidatedPrice();
    }

    function test_Fork_MockUSDC_Mainnet() public {
        string memory rpc = vm.envOr("MAINNET_RPC", string("https://eth.llamarpc.com"));
        try vm.createSelectFork(rpc) {} catch {
            vm.skip(true);
            return;
        }
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        (bool ok, bytes memory data) = usdc.staticcall(abi.encodeWithSignature("totalSupply()"));
        assertTrue(ok);
        assertGt(abi.decode(data, (uint256)), 0);
    }
}
