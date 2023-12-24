// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMiningReferral {
    function recordReferralCommission(
        address _referrer,
        uint256 _commission
    ) external;

    function getReferrer(address _user) external view returns (address);

    function baseRate() external view returns (uint256);

    function bonusRate(address _user) external view returns (uint256);
}
