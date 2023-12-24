// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MiningReferral is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public operators;
    mapping(address => address) public referrers; // user address => referrer address

    mapping(address => uint256) public referralsCount; // referrer address => referrals count
    mapping(address => address[]) public referrals; // referrer address => referrals list
    mapping(address => uint256) public totalReferralCommissions; // referrer address => total referral commissions

    mapping(address => bool) public authorized; // referrer address => authorized
    mapping(address => uint256) public bonusRate; // referrer address => bonus rate if registered

    uint256 public baseRate = 500;

    event ReferralRecorded(address indexed user, address indexed referrer);
    event ReferralCommissionRecorded(
        address indexed referrer,
        uint256 commission
    );
    event OperatorUpdated(address indexed operator, bool indexed status);

    modifier onlyOperator() {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    constructor() Ownable() {
        operators[msg.sender] = true;
    }

    function recordReferral(address _user, address _referrer) public {
        // require(authorized[_referrer], "Referrer is not authorized");

        require(_user == msg.sender || operators[msg.sender], "Not authorized");

        if (
            _user != address(0) &&
            _referrer != address(0) &&
            _user != _referrer &&
            referrers[_user] == address(0)
        ) {
            referrers[_user] = _referrer;

            referralsCount[_referrer] += 1;
            referrals[_referrer].push(_user);
            emit ReferralRecorded(_user, _referrer);
        }
    }

    function recordReferralCommission(
        address _referrer,
        uint256 _commission
    ) public onlyOperator {
        if (_referrer != address(0) && _commission > 0) {
            totalReferralCommissions[_referrer] += _commission;
            emit ReferralCommissionRecorded(_referrer, _commission);
        }
    }

    // Get the referrer address that referred the user
    function getReferrer(address _user) public view returns (address) {
        return referrers[_user];
    }

    function getReferralsList(
        address _referrer
    ) public view returns (address[] memory) {
        return referrals[_referrer];
    }

    function setAuthorized(
        address _referrer,
        bool _status,
        uint256 _bonusRate
    ) external onlyOwner {
        authorized[_referrer] = _status;
        bonusRate[_referrer] = _bonusRate;
    }

    function getBonusRate(address _user) public view returns (uint256) {
        address userReferral = referrers[_user];
        if (userReferral == address(0) || !authorized[userReferral]) {
            return baseRate;
        }
        return bonusRate[userReferral];
    }

    function referralInfoForUser(
        address _user
    )
        external
        view
        returns (
            address _referrer,
            uint256 _referralsCount,
            address[] memory _referrals,
            uint256 _totalReferralCommissions
        )
    {
        return (
            referrers[_user],
            referralsCount[_user],
            referrals[_user],
            totalReferralCommissions[_user]
        );
    }

    // Update the status of the operator
    function updateOperator(
        address _operator,
        bool _status
    ) external onlyOwner {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    // Owner can drain tokens that are sent here by mistake
    function recoverERC20Token(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        _token.safeTransfer(_to, _amount);
    }
}
