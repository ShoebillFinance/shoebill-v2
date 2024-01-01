// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IGovSBL.sol";

/// @title LinearUnstakingStage
/// @notice Implements  unstaking GovSBL to SBL with linear release
/// @dev Unstaking amount will be released linearly during unstaking period
/// @dev User can claim, or restake during unstaking period
/// @dev Every Unstakes will claim releasable amount and restart unstaking period
contract LinearUnstakingStage is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public gShoebillToken;
    address public shoebillToken;

    struct UnstakingInfo {
        uint256 unstakeAmount;
        uint256 lastClaimTimestamp;
        uint256 completeTimestamp;
    }
    mapping(address /* user */ => UnstakingInfo) public unstakingRequest;

    uint256 public unstakingPeriod;

    event UpdateUnstakingPeriod(uint256 unstakingPeriod);
    event EnterUnstakingStage(
        address indexed user,
        uint256 amount,
        uint256 completeTime
    );
    event Claim(address indexed user, uint256 amount);
    event Restake(address indexed user, uint256 amount);

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

        unstakingPeriod = 40 days;
    }

    function updateUnstakingPeriod(
        uint256 _unstakingPeriod
    ) external onlyOwner {
        unstakingPeriod = _unstakingPeriod;
        emit UpdateUnstakingPeriod(unstakingPeriod);
    }

    /// @notice Unstake function called by GShoebillToken
    /// @dev 1. claim releasable amount 2. restart unstaking period including (un-released amount + new amount)
    /// @param user The user address
    /// @param amount Amounts of tokens that user want to unstake
    function enterUnstakingStage(
        address user,
        uint256 amount
    ) external onlyGShoebillToken {
        UnstakingInfo storage info = unstakingRequest[user];

        if (info.unstakeAmount > 0) {
            uint256 claimableAmount;
            if (block.timestamp >= info.completeTimestamp) {
                claimableAmount = info.unstakeAmount;
            } else {
                uint256 timeDelta = block.timestamp - info.lastClaimTimestamp;
                claimableAmount =
                    (info.unstakeAmount * timeDelta) /
                    unstakingPeriod;
            }

            info.unstakeAmount -= claimableAmount;
            IERC20(shoebillToken).safeTransfer(user, claimableAmount);

            emit Claim(user, claimableAmount);
        }

        IERC20(shoebillToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        info.unstakeAmount += amount;
        info.lastClaimTimestamp = block.timestamp;
        info.completeTimestamp = block.timestamp + unstakingPeriod;

        emit EnterUnstakingStage(user, amount, info.completeTimestamp);
    }

    /// @dev 1. claim releasable amount
    /// @param user The user address
    function claim(address user) external {
        UnstakingInfo storage info = unstakingRequest[user];

        if (info.unstakeAmount > 0) {
            uint256 claimableAmount;
            // unstake complete
            if (block.timestamp >= info.completeTimestamp) {
                claimableAmount = info.unstakeAmount;
            } else {
                uint256 timeDelta = block.timestamp - info.lastClaimTimestamp;
                claimableAmount =
                    (info.unstakeAmount * timeDelta) /
                    unstakingPeriod;
            }

            info.unstakeAmount -= claimableAmount;
            IERC20(shoebillToken).safeTransfer(user, claimableAmount);

            emit Claim(user, claimableAmount);
        }
        info.lastClaimTimestamp = block.timestamp;
    }

    function getUserInfo(
        address user
    )
        external
        view
        returns (
            uint256 remaining,
            uint256 claimable,
            uint256 completeTimestamp
        )
    {
        UnstakingInfo memory info = unstakingRequest[user];

        remaining = info.unstakeAmount;

        if (info.unstakeAmount > 0) {
            // unstake complete
            if (block.timestamp >= info.completeTimestamp) {
                claimable = info.unstakeAmount;
            } else {
                uint256 timeDelta = block.timestamp - info.lastClaimTimestamp;
                claimable = (info.unstakeAmount * timeDelta) / unstakingPeriod;
            }
        }

        completeTimestamp = info.completeTimestamp;
    }

    /// @notice Restake function
    /// @dev 1. All unstake amount will be restaked onbehalf of msg sender (releasable + unreleased amount)
    function restake() external {
        UnstakingInfo storage info = unstakingRequest[msg.sender];
        require(info.unstakeAmount > 0, "No unstake amount");

        info.lastClaimTimestamp = block.timestamp;
        info.completeTimestamp = block.timestamp + unstakingPeriod;
        info.unstakeAmount = 0;

        IERC20(shoebillToken).approve(gShoebillToken, info.unstakeAmount);

        IGovSBL(gShoebillToken).stake(msg.sender, info.unstakeAmount);

        emit Restake(msg.sender, info.unstakeAmount);
    }

    function totalUnstakingAmount() external view returns (uint256) {
        return IERC20(shoebillToken).balanceOf(address(this));
    }
}
