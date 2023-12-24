// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IGovernanceShoebillToken.sol";

contract PenaltyUnstakingStage is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public gShoebillToken;
    address public shoebillToken;

    uint256 public penaltyRate; // how much user unstaking amount will be deducted
    uint256 public holderRate; // how much user's penalty amount will be given to holder
    uint256 public discountRate; // how much bonus amount will be given to user

    event UpdatePenaltyRate(uint256 penaltyRate);
    event UpdateDiscountRate(uint256 discountRate);
    event UpdateHolderRate(uint256 holderRate);

    event EnterUnstakingStage(
        address indexed user,
        uint256 amount,
        uint256 penaltyAmount,
        uint256 holderAmount
    );
    event BuyGSBT(address indexed user, uint256 burnAmount, uint256 amount);

    modifier onlyGShoebillToken() {
        require(msg.sender == gShoebillToken, "Only GShoebillToken");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _shoebillToken,
        address _gShoebillToken
    ) external initializer {
        __Ownable_init();
        shoebillToken = _shoebillToken;
        gShoebillToken = _gShoebillToken;

        penaltyRate = 8000;
        holderRate = 5000;
        discountRate = 5000;
    }

    function updatePenaltyRate(uint256 _penaltyRate) external onlyOwner {
        penaltyRate = _penaltyRate;

        emit UpdatePenaltyRate(_penaltyRate);
    }

    function updateDiscountRate(uint256 _discountRate) external onlyOwner {
        discountRate = _discountRate;

        emit UpdateDiscountRate(_discountRate);
    }

    function updateHolderRate(uint256 _holderRate) external onlyOwner {
        holderRate = _holderRate;

        emit UpdateHolderRate(_holderRate);
    }

    /// @notice Penalty Unstake function called by GShoebillToken
    /// @dev Only GShoebillToken can call this function
    /// @param user The user address
    /// @param amount Amounts of tokens that user want to unstake
    function enterUnstakingStage(
        address user,
        uint256 amount
    ) external onlyGShoebillToken {
        IERC20(shoebillToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        uint256 penaltyAmount = (amount * penaltyRate) / 10000;

        IERC20(shoebillToken).safeTransfer(user, amount - penaltyAmount);

        uint256 holderAmount = (penaltyAmount * holderRate) / 10000;

        IERC20(shoebillToken).safeTransfer(msg.sender, holderAmount);

        emit EnterUnstakingStage(user, amount, penaltyAmount, holderAmount);
    }

    /// @notice Buy G.SBT
    /// @dev User can acquire G.SBT through buying G.SBT with bonus
    /// @param amount SBT amount to buy G.SBT
    function buyGSBT(uint256 amount) external {
        uint256 currentAvailableAmount = IERC20(shoebillToken).balanceOf(
            address(this)
        );
        require(currentAvailableAmount >= amount, "Not enough sale amount");

        uint256 discountedAmount = (amount * discountRate) / 10000;

        // discounted amount from user will be burned
        IERC20(shoebillToken).safeTransferFrom(
            msg.sender,
            address(0),
            discountedAmount
        );

        IERC20(shoebillToken).approve(gShoebillToken, amount);

        IGovernanceShoebillToken(gShoebillToken).stake(msg.sender, amount);

        emit BuyGSBT(msg.sender, discountedAmount, amount);
    }

    // available amount to buy g.sbt
    function availableInAmount() external view returns (uint256) {
        return IERC20(shoebillToken).balanceOf(address(this));
    }
}
