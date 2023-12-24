// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IGovernanceShoebillToken {
    function stake(address user, uint256 amount) external;

    function getBoostMultiplier(address user) external view returns (uint256);
}
