// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IGovernanceShoebillToken.sol";

interface ISBP {
    function devBurn(address target, uint256 amount) external;
}

contract SBPToGSBTConverter is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public endTime;

    address public shoebillPoint;
    address public shoebillToken;
    address public gShoebillToken;
    uint256 public convertRate;

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

    function convert() external {
        require(block.timestamp < endTime, "End time");
        uint256 amount = IERC20(shoebillPoint).balanceOf(msg.sender);
        require(amount > 0, "No balance");

        // require : get dev role
        ISBP(shoebillPoint).devBurn(msg.sender, amount);

        // get convert amount
        uint256 convertAmount = pointToToken(amount);
        IERC20(shoebillToken).approve(gShoebillToken, convertAmount);
        // require : have enough sbt
        IGovernanceShoebillToken(gShoebillToken).stake(
            msg.sender,
            convertAmount
        );
    }

    function pointToToken(uint256 amount) public view returns (uint256) {
        return convertRate * amount;
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

        IGovernanceShoebillToken(gShoebillToken).stake(
            msg.sender,
            convertAmount
        );
        uint256 afterBal = IERC20(gShoebillToken).balanceOf(_user);

        estGShoebillAmount = afterBal - beforeBal;
    }
}
