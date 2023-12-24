// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// import ierc721receiver
interface ILinearUnstakingStage {
    function enterUnstakingStage(address user, uint256 amount) external;
}

interface IPenaltyUnstakingStage {
    function enterUnstakingStage(address user, uint256 amount) external;
}

interface IRewardDistributor {
    function claim(address[] memory holders) external;
}

contract GovernanceShoebillToken is
    ERC20Upgradeable,
    OwnableUpgradeable,
    IERC721Receiver
{
    using SafeERC20 for IERC20;

    uint256 public totalStaked; // total balance of sbp
    IERC20 public token; // sbp

    ILinearUnstakingStage public linearUnstakingStage;
    IPenaltyUnstakingStage public penaltyUnstakingStage;
    IRewardDistributor public rewardDistributor;

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

    // =============================== EVENT ===================================

    event SetLinearUnstakingStage(address indexed linearUnstakingStage);
    event SetPenaltyUnstakingStage(address indexed penaltyUnstakingStage);
    event SetRewardDistributor(address indexed rewardDistributor);
    event Stake(address indexed user, uint256 amount, uint256 shares);
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

    function initialize(address _token) external initializer {
        __Governance_init();
        token = IERC20(_token);

        maxBoostMultiplier = 20000;

        balanceTierRequired.push(1000 ether);
        balanceTierMultiplier[0] = 10500; // 1.05x

        balanceTierRequired.push(2000 ether);
        balanceTierMultiplier[1] = 11250; // 1.125

        balanceTierRequired.push(3000 ether);
        balanceTierMultiplier[2] = 12500; // 1.25x

        // if user hld more than 6000 sbp, they will get 1.05x * 1.125x * 1.25x = 1.40625x
    }

    function __Governance_init() internal initializer {
        __ERC20_init("Governance Shoebill Token", "G.SBT");
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

    function setRewardDistributor(
        address _rewardDistributor
    ) external onlyOwner {
        rewardDistributor = IRewardDistributor(_rewardDistributor);

        emit SetRewardDistributor(_rewardDistributor);
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
        _stake(_user, token.balanceOf(msg.sender));
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

    function stakeNFT(IERC721 _nft) external {
        _stakeNFT(_nft);
    }

    // =============================== INTERNAL ===================================

    /// @notice Stake sbp to g.sbp
    /// @dev boost changed, balance changed, transferFrom user
    /// @param _user user address, can be msg sender or delegatee
    /// @param _amount amount of sbp
    function _stake(address _user, uint256 _amount) internal {
        _beforeAction(_user);

        uint256 shares;
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply_) / token.balanceOf(address(this));
        }

        token.safeTransferFrom(msg.sender, address(this), _amount);

        _mint(_user, shares);
        totalStaked += _amount;

        emit Stake(_user, _amount, shares);
    }

    /// @notice Unstake g.sbp to sbp with vesting
    /// @dev boost changed, balance changed, send to linearUnstakingStage
    /// @param _shares balance of g.sbp
    /// @param _unstakingStage 0 = linear, 1 = penalty
    function _unstake(uint256 _shares, uint256 _unstakingStage) internal {
        _beforeAction(msg.sender);
        uint256 amount = (_shares * token.balanceOf(address(this))) /
            totalSupply();

        _burn(msg.sender, _shares);
        totalStaked -= amount;

        if (_unstakingStage == 0) {
            IERC20(token).approve(address(linearUnstakingStage), amount);
            linearUnstakingStage.enterUnstakingStage(msg.sender, amount);
            emit Unstake(msg.sender, amount, _shares, _unstakingStage);
        } else if (_unstakingStage == 1) {
            IERC20(token).approve(address(penaltyUnstakingStage), amount);
            penaltyUnstakingStage.enterUnstakingStage(msg.sender, amount);
            emit Unstake(msg.sender, amount, _shares, _unstakingStage);
        } else {
            revert("Invalid unstaking stage");
        }
    }

    /// @notice Stake Approved boost item NFT
    /// @dev boost changed,  transferFrom nft to user
    /// @param _nft nft address
    function _stakeNFT(IERC721 _nft) internal {
        _beforeAction(msg.sender);

        _nft.safeTransferFrom(msg.sender, address(this), 1);

        nftBalance[msg.sender][address(_nft)] += 1;
    }

    /// @notice Before action hook
    /// @dev claim reward before re-calculate boost
    function _beforeAction(address _user) internal {
        address[] memory holders = new address[](1);
        holders[0] = _user;
        rewardDistributor.claim(holders);
    }

    // =============================== VIEW ===================================

    /// @notice Get boost multiplier from staked amount
    function getBalanceTierAndBoost(
        address _user
    ) public view returns (uint256) {
        uint256 boostMultiplier = 10000;

        for (uint256 i; i < balanceTierRequired.length; i++) {
            uint256 staked = balanceOf(_user);
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
            for (uint256 j; j < nftBalance[_user][boostNft[i]]; j++) {
                boostMultiplier =
                    (boostMultiplier * boostNftMultiplier[boostNft[i]]) /
                    10000;
            }
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

    // =============================== OVERRIDEN ===================================

    // can not transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // claim reward before re-calculate boost
        _beforeAction(from);
        _beforeAction(to);

        super._beforeTokenTransfer(from, to, amount);
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
