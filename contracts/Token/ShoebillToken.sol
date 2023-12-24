// SPDX-License-Identifier: MIT

pragma solidity =0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShoebillToken is ERC20 {
    uint256 public constant MAX_SUPPLY = 100_000_000 ether;

    constructor() ERC20("Shoebill Token", "SBT") {
        _mint(msg.sender, MAX_SUPPLY);
    }
}
