// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface StWemixInterface {
    function phaseShift() external;

    function feeUpdate(uint256 newFeePhaseTwo) external;

    //=============== View Functions ===============//

    function getTotalPooledWEMIXWithFee() external returns (uint256);

    function rewardOf(
        address account_
    ) external view returns (uint256 rewardOf_);

    function fee() external view returns (uint256 fee_);

    function getSharesByPooledWEMIXWithFee(
        uint256 wemixAmount_
    ) external view returns (uint256 shareAmount_);

    function getPooledWEMIXBySharesWithFee(
        uint256 shareAmount_
    ) external view returns (uint256 wemixAmount_);

    //=============== Deposit & Withdraw ===============//

    function deposit() external payable returns (uint256);

    function withdraw(uint256 amount_) external payable returns (uint256);

    function compound() external;
}
