// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract GovernanceTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function test_VotingDelay() public view {
        assertEq(governor.votingDelay(), 7200);
    }

    function test_VotingPeriod() public view {
        assertEq(governor.votingPeriod(), 50400);
    }

    function test_ProposalThreshold() public view {
        assertEq(governor.proposalThreshold(), 10_000 ether);
    }

    function test_Quorum() public {
        vm.roll(block.number + 1);
        assertGt(governor.quorum(block.number - 1), 0);
    }

    function test_DelegateVotingPower() public {
        vm.prank(admin);
        govToken.transfer(alice, 50_000 ether);
        vm.prank(alice);
        govToken.delegate(alice);
        assertGt(govToken.getVotes(alice), 0);
    }

    function test_TimelockDelay() public view {
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function test_ProposeVoteQueueExecute() public {
        vm.roll(block.number + 1);
        _createMarket(admin, 0);
        address[] memory targets = new address[](1);
        targets[0] = address(factory);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "createMarket(string,string,int256,uint8,uint256,uint256)",
            "DAO market",
            "Crypto",
            3000e8,
            1,
            block.timestamp + 30 days,
            0
        );
        vm.prank(admin);
        uint256 pid = governor.propose(targets, values, calldatas, "Create market via DAO");
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Pending));
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(admin);
        governor.castVote(pid, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descHash = keccak256(bytes("Create market via DAO"));
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Succeeded));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        governor.execute(targets, values, calldatas, descHash);
        assertGt(factory.marketCount(), 0);
    }
}
