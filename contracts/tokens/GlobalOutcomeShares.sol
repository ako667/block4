// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title GlobalOutcomeShares — single ERC-1155 for all markets
/// @dev Market 1: ID 1 = YES, ID 2 = NO. Market 2: ID 3 = YES, ID 4 = NO.
contract GlobalOutcomeShares is ERC1155, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(address admin) ERC1155("https://api.pmt.dev/outcome/{id}.json") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function yesTokenId(uint256 marketId) public pure returns (uint256) {
        return marketId * 2 - 1;
    }

    function noTokenId(uint256 marketId) public pure returns (uint256) {
        return marketId * 2;
    }

    function mint(address to, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, id, amount);
    }

    function grantMarketEngine(address engine) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, engine);
        _grantRole(BURNER_ROLE, engine);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
