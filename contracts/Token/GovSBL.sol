// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ILinearUnstakingStage {
    function enterUnstakingStage(address user, uint256 amount) external;
}

interface IPenaltyUnstakingStage {
    function enterUnstakingStage(address user, uint256 amount) external;
}

interface IClaimComp {
    function claimComp(address holder) external;
}

interface IExteranlMultiRewarder {
    function refreshReward(address _user) external;
    function refreshAndGetReward(address _user) external;
}

/// @title GovSBL
/// @notice Shoebill Governance staking contract
/// @dev G.SBL has tier system, boost from staked amount and boost from NFT with max boost
/// @dev G.SBL can be unstaked with linear vesting or penalty vesting
/// @dev G.SBL holder can earn external reward.
contract GovSBL is ERC20Upgradeable, OwnableUpgradeable, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC20 public shoebill; // SBL

    ILinearUnstakingStage public linearUnstakingStage;
    IPenaltyUnstakingStage public penaltyUnstakingStage;

    IClaimComp[] public unitrollers; // unitrollers (manta has 2 markets)

    IExteranlMultiRewarder public externalMultiRewarder;

    // =============================== BOOST ===================================
    uint256 public maxBoostMultiplier; // 100% => 2x // denominator: 10000

    // user => nft => balance
    mapping(address => mapping(address => uint256)) public nftBalance;
    // NFT => bool
    address[] public boostNft;
    // NFT => boostMultiplier
    mapping(address => uint256) public boostNftMultiplier;
    // Balance Tier / amount required
    uint256[] public balanceTierRequired;
    // Balance Tier => multiplier
    mapping(uint256 => uint256) public balanceTierMultiplier; // 11000 = 10% boost

    // =============================== ADDED ===================================

    uint256 public deployedAt;

    // =============================== EVENT ===================================

    event SetLinearUnstakingStage(address indexed linearUnstakingStage);
    event SetPenaltyUnstakingStage(address indexed penaltyUnstakingStage);
    event SetExternalRewarder(address indexed rewarder);
    event Stake(address indexed user, uint256 amount, uint256 shares);
    event StakeNFT(address indexed user, address indexed nft, uint256 tokenId);
    event Unstake(
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 unstakingStage
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _shoebill) external initializer {
        __Governance_init();
        shoebill = IERC20(_shoebill);

        maxBoostMultiplier = 10000; // 1x at start
        // maxBoostMultiplier = 20000;

        balanceTierRequired.push(1000 ether);
        balanceTierMultiplier[0] = 10500; // 1.05x

        balanceTierRequired.push(2000 ether);
        balanceTierMultiplier[1] = 11250; // 1.125

        balanceTierRequired.push(3000 ether);
        balanceTierMultiplier[2] = 12500; // 1.25x

        // if user hld more than 3000 sbp, they will get 1.05x * 1.125x * 1.25x = 1.40625x

        deployedAt = block.timestamp;
    }

    function __Governance_init() internal initializer {
        __ERC20_init("Governance Shoebill", "gSBL");
        __Ownable_init();
    }

    // =============================== SETTER ===================================

    function setLinearUnstakingStage(
        address _linearUnstakingStage
    ) external onlyOwner {
        linearUnstakingStage = ILinearUnstakingStage(_linearUnstakingStage);

        emit SetLinearUnstakingStage(_linearUnstakingStage);
    }

    function setPenaltyUnstakingStage(
        address _penaltyUnstakingStage
    ) external onlyOwner {
        linearUnstakingStage = ILinearUnstakingStage(_penaltyUnstakingStage);

        emit SetPenaltyUnstakingStage(_penaltyUnstakingStage);
    }

    function setExternalMultiRewarder(
        address _externalMultiRewarder
    ) external onlyOwner {
        externalMultiRewarder = IExteranlMultiRewarder(_externalMultiRewarder);

        emit SetExternalRewarder(_externalMultiRewarder);
    }

    function addUnitroller(address _unitroller) external onlyOwner {
        unitrollers.push(IClaimComp(_unitroller));
    }

    function removeUnitroller(address _unitroller) external onlyOwner {
        for (uint256 i = 0; i < unitrollers.length; i++) {
            if (address(unitrollers[i]) == _unitroller) {
                unitrollers[i] = unitrollers[unitrollers.length - 1];
                unitrollers.pop();
                break;
            }
        }
    }

    function addTier(uint256 _amount, uint256 _boost) external onlyOwner {
        balanceTierRequired.push(_amount);
        balanceTierMultiplier[balanceTierRequired.length - 1] = _boost;
    }

    function removeTier() external onlyOwner {
        balanceTierRequired.pop();
        balanceTierMultiplier[balanceTierRequired.length] = 0;
    }

    function updateTier(
        uint256 _index,
        uint256 _amount,
        uint256 _boost
    ) external onlyOwner {
        balanceTierRequired[_index] = _amount;
        balanceTierMultiplier[_index] = _boost;
    }

    function setMaxBoostMultiplier(
        uint256 _maxBoostMultiplier
    ) external onlyOwner {
        maxBoostMultiplier = _maxBoostMultiplier;
    }

    function addBoostNft(address _nft) external onlyOwner {
        boostNft.push(_nft);
    }

    function removeBoostNft(address _nft) external onlyOwner {
        for (uint256 i = 0; i < boostNft.length; i++) {
            if (boostNft[i] == _nft) {
                boostNft[i] = boostNft[boostNft.length - 1];
                boostNft.pop();
                break;
            }
        }
    }

    function setBoostNftMultiplier(
        address _nft,
        uint256 _multiplier
    ) external onlyOwner {
        boostNftMultiplier[_nft] = _multiplier;
    }

    // =============================== External ===================================

    function stake(address _user, uint256 _amount) external {
        _stake(_user, _amount);
    }

    function stakeAll(address _user) external {
        _stake(_user, shoebill.balanceOf(msg.sender));
    }

    function unstake(
        uint256 _shares,
        uint256 _unstakingStage /* 0 = linear, 1 = penalty*/
    ) external {
        _unstake(_shares, _unstakingStage);
    }

    function unstakeAll(uint256 _unstakingStage) external {
        _unstake(balanceOf(msg.sender), _unstakingStage);
    }

    function stakeNFT(IERC721 _nft, uint256[] memory _tokenIds) external {
        for (uint256 i; i < _tokenIds.length; i++) {
            _stakeNFT(_nft, _tokenIds[i]);
        }
    }

    // =============================== INTERNAL ===================================

    /// @notice Stake sbp to g.sbp
    /// @dev boost changed, balance changed, transferFrom user
    /// @param _user user address, can be msg sender or delegatee
    /// @param _amount amount of sbp
    function _stake(address _user, uint256 _amount) internal {
        _beforeAction(_user);

        if (_amount > 0) {
            uint256 shares;
            uint256 totalSupply_ = totalSupply();
            if (totalSupply_ == 0) {
                shares = _amount;
            } else {
                shares =
                    (_amount * totalSupply_) /
                    shoebill.balanceOf(address(this));
            }

            shoebill.safeTransferFrom(msg.sender, address(this), _amount);

            _mint(_user, shares);

            emit Stake(_user, _amount, shares);
        }
    }

    /// @notice Unstake g.sbp to sbp with vesting
    /// @dev boost changed, balance changed, send to linearUnstakingStage
    /// @param _shares balance of g.sbp
    /// @param _unstakingStage 0 = linear, 1 = penalty
    function _unstake(uint256 _shares, uint256 _unstakingStage) internal {
        _beforeAction(msg.sender);
        uint256 amount = (_shares * shoebill.balanceOf(address(this))) /
            totalSupply();

        _burn(msg.sender, _shares);

        if (_unstakingStage == 0) {
            IERC20(shoebill).approve(address(linearUnstakingStage), amount);
            linearUnstakingStage.enterUnstakingStage(msg.sender, amount);
            emit Unstake(msg.sender, amount, _shares, _unstakingStage);
        } else if (_unstakingStage == 1) {
            IERC20(shoebill).approve(address(penaltyUnstakingStage), amount);
            penaltyUnstakingStage.enterUnstakingStage(msg.sender, amount);
            emit Unstake(msg.sender, amount, _shares, _unstakingStage);
        } else {
            revert("Invalid unstaking stage");
        }
    }

    /// @notice Stake Approved boost item NFT
    /// @dev boost changed,  transferFrom nft to user
    /// @param _nft nft address
    function _stakeNFT(IERC721 _nft, uint256 _tokenId) internal {
        _beforeAction(msg.sender);

        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        nftBalance[msg.sender][address(_nft)] += 1;

        emit StakeNFT(msg.sender, address(_nft), _tokenId);
    }

    /// @notice Before action hook
    /// @dev claim reward before re-calculate boost
    function _beforeAction(address _user) internal {
        // 1. call extenal reward (boost x) based on g.sbl balance
        if (address(externalMultiRewarder) != address(0)) {
            try externalMultiRewarder.refreshAndGetReward(_user) {} catch {}
        }

        // 2. claim unitroller reward (boost, refferal)
        for (uint256 i; i < unitrollers.length; i++) {
            unitrollers[i].claimComp(_user);
        }
    }

    // =============================== VIEW ===================================

    /// @notice Get boost multiplier from staked amount
    function getBalanceTierAndBoost(
        address _user
    ) public view returns (uint256) {
        uint256 boostMultiplier = 10000;

        uint256 staked = balanceOf(_user);
        for (uint256 i; i < balanceTierRequired.length; i++) {
            if (staked >= balanceTierRequired[i]) {
                boostMultiplier =
                    (boostMultiplier * balanceTierMultiplier[i]) /
                    10000;
            }
        }

        return boostMultiplier < 10000 ? 10000 : boostMultiplier;
    }

    function getNftBoost(address _user) public view returns (uint256) {
        uint256 boostMultiplier = 10000;

        for (uint256 i; i < boostNft.length; i++) {
            boostMultiplier =
                boostMultiplier +
                nftBalance[_user][boostNft[i]] *
                boostNftMultiplier[boostNft[i]];
        }

        return boostMultiplier < 10000 ? 10000 : boostMultiplier;
    }

    function getBoostMultiplier(address _user) external view returns (uint256) {
        uint256 boostMultiplier = 10000;
        // 1. get boost multiplier from staked amount
        boostMultiplier =
            (boostMultiplier * getBalanceTierAndBoost(_user)) /
            10000;

        // 2. get boost multiplier from nft
        boostMultiplier = (boostMultiplier * getNftBoost(_user)) / 10000;

        // 3. get max boost multiplier
        if (boostMultiplier > maxBoostMultiplier) {
            boostMultiplier = maxBoostMultiplier;
        }

        return boostMultiplier;
    }

    function balanceTierInfo() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](balanceTierRequired.length);
        for (uint256 i; i < balanceTierRequired.length; i++) {
            result[i] = balanceTierRequired[i];
        }

        return result;
    }

    // =============================== OVERRIDEN ===================================

    // can not transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(
            from == address(0) || to == address(0),
            "gSBL: transfer disabled"
        );
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    uint256[50] private __gap;
}
