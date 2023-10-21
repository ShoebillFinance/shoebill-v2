// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import {CEther} from "./CEther.sol";

/// @title PrincipalPool
/// @author Shoebill
/// @notice Claim interests earned from the cToken
/// @dev Will be used if get grant from any governance.

contract PrincipalPool {
    address payable public immutable cToken;

    address public immutable depositor;
    address public immutable interestReceiver;

    uint256 public principal;
    uint256 public sharing = 10000;
    uint256 public denominator = 10000;

    constructor(
        address payable _cToken,
        address _depositer,
        address _interestReceiver
    ) {
        require(_cToken != address(0), "cToken is zero address");
        require(_depositer != address(0), "depositer is zero address");
        require(
            _interestReceiver != address(0),
            "interestReceiver is zero address"
        );

        cToken = _cToken;
        depositor = _depositer;
        interestReceiver = _interestReceiver;
    }

    function enter() external payable {
        CEther(cToken).mint{value: msg.value}();

        principal += msg.value;
    }

    function _enter() internal {
        CEther(cToken).mint{value: msg.value}();

        principal += msg.value;
    }

    function exit(uint256 amount) external {
        CEther(cToken).redeemUnderlying(amount);

        principal -= amount;

        (bool suc, ) = depositor.call{value: amount}("");
        require(suc, "transfer failed");
    }

    function exitCToken(uint256 amount) external {
        uint256 underlyingAmount = (CEther(cToken).exchangeRateCurrent() *
            amount) / 1e18;

        principal -= underlyingAmount;

        require(CEther(cToken).transfer(depositor, amount), "transfer failed");
    }

    function claim() external {
        uint256 balance = CEther(cToken).balanceOfUnderlying(address(this));
        uint256 interest = balance - principal;
        uint256 interestToShare = (interest * sharing) / denominator;

        uint256 toPrincipal = interest - interestToShare;

        if (toPrincipal > 0) {
            principal += toPrincipal;
        }

        CEther(cToken).redeemUnderlying(interestToShare);

        (bool suc, ) = interestReceiver.call{value: interestToShare}("");
        require(suc, "transfer failed");
    }

    receive() external payable {}
}
