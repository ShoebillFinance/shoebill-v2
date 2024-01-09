// SPDX-License-Identifier: MIT

pragma solidity =0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IGovSBL.sol";

/// @title SBP to GovSBL Converter
/// @notice Convert ShoebillPoint ERC20 token to GovSBL ERC20 token with pre-defined rate
/// @dev SBL Amounts should be transferred to this contract before calling convert function
contract SBPToGovSBLConverter is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public endTime; // converter has end time

    address public shoebillPoint; // sbp token address
    address public shoebillToken; // SBL
    address public gShoebillToken; // govSBL
    uint256 public convertRate; // sbp to sbl rate in 1e18 (sbp * convertRate / 1e18 = sbl)

    mapping(address => uint256) sbpCommitments;
    uint256 totalSbpCommitments;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _shoebillPoint,
        address _shoebillToken,
        address _gShoebillToken,
        uint256 _convertRate
    ) external initializer {
        __Ownable_init();
        shoebillPoint = _shoebillPoint;
        shoebillToken = _shoebillToken;
        gShoebillToken = _gShoebillToken;
        convertRate = _convertRate;

        endTime = block.timestamp + 30 days;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        endTime = _endTime;
    }

    function setConvertRate(uint256 _convertRate) external onlyOwner {
        convertRate = _convertRate;
    }

    /// @notice Withdraw all ERC20 after end time
    /// @param _token ERC20 token address
    /// @dev withdraw function if there is unconverted SBL token
    function withdrawAfterEnd(address _token) external onlyOwner {
        require(block.timestamp > endTime, "Not end");
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /// @notice Convert ShoebillPoint ERC20 token to GovSBL ERC20 token with pre-defined rate
    function convert() external {
        require(block.timestamp < endTime, "End time");
        uint256 amount = IERC20(shoebillPoint).balanceOf(msg.sender);
        require(amount > 0, "No balance");

        IERC20(shoebillPoint).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        sbpCommitments[msg.sender] += amount;
        totalSbpCommitments += amount;

        uint256 convertAmount = pointToToken(amount);

        IERC20(shoebillToken).approve(gShoebillToken, convertAmount);

        IGovSBL(gShoebillToken).stake(msg.sender, convertAmount);
    }

    function pointToToken(uint256 amount) public view returns (uint256) {
        return (convertRate * amount) / 1e18;
    }

    function convertInfo()
        external
        view
        returns (uint256 _convertRate, uint256 _endTime)
    {
        _convertRate = convertRate;
        _endTime = endTime;
    }

    function convertInfoAuth(
        address _user
    )
        external
        returns (
            uint256 pointAmount,
            uint256 estShoebillAmount,
            uint256 estGShoebillAmount
        )
    {
        pointAmount = IERC20(shoebillPoint).balanceOf(_user);

        uint256 beforeBal = IERC20(gShoebillToken).balanceOf(_user);

        uint256 convertAmount = pointToToken(pointAmount);
        estShoebillAmount = convertAmount;

        IERC20(shoebillToken).approve(gShoebillToken, convertAmount);

        IGovSBL(gShoebillToken).stake(msg.sender, convertAmount);
        uint256 afterBal = IERC20(gShoebillToken).balanceOf(_user);

        estGShoebillAmount = afterBal - beforeBal;
    }
}
