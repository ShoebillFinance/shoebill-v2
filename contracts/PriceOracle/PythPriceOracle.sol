// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "../PriceOracle.sol";
import "../StWemixInterface.sol";

contract PythPriceOracle is PriceOracle {
    mapping(string => IPyth) public priceFeeds;
    mapping(string => uint256) public baseUnits;
    mapping(string => bytes32) public priceIds;

    string public constant stWEMIXSymbol = "sbstWEMIX";
    address public constant stWEMIX =
        0x9B377bd7Db130E8bD2f3641E0E161cB613DA93De;
    uint256 public constant age = 60 * 15;

    constructor(
        string[] memory symbols_,
        IPyth[] memory feeds_,
        uint256[] memory baseUnits_,
        bytes32[] memory priceIds_
    ) {
        for (uint256 i = 0; i < symbols_.length; i++) {
            priceFeeds[symbols_[i]] = feeds_[i];
            baseUnits[symbols_[i]] = baseUnits_[i];
            priceIds[symbols_[i]] = priceIds_[i];
        }
    }

    // price in 18 decimals
    function getPrice(CToken cToken) public view override returns (uint256) {
        string memory symbol = cToken.symbol();

        (uint256 price, ) = _getLatestPrice(symbol);

        return price * 10 ** 10;
    }

    // price is extended for comptroller usage based on decimals of exchangeRate
    function getUnderlyingPrice(
        CToken cToken
    ) external view override returns (uint256) {
        string memory symbol = cToken.symbol();
        uint256 feedDecimals = 8;

        (uint256 price, ) = _getLatestPrice(symbol);
        return (price * (10 ** (36 - feedDecimals))) / baseUnits[symbol];
    }

    function _getLatestPrice(
        string memory symbol
    ) internal view returns (uint256, uint256) {
        require(address(priceFeeds[symbol]) != address(0), "missing priceFeed");

        PythStructs.Price memory priceData = priceFeeds[symbol]
            .getPriceNoOlderThan(priceIds[symbol], age);

        require(priceData.price > 0, "price cannot be zero");
        uint256 uPrice = uint256(uint64(priceData.price));

        if (compareString(symbol, stWEMIXSymbol)) {
            uPrice = (uPrice * _calcStWemix()) / 1e8;
        }

        return (uPrice, priceData.publishTime);
    }

    function _calcStWemix() internal view returns (uint256) {
        uint256 rate = StWemixInterface(stWEMIX).getPooledWEMIXBySharesWithFee(
            1e8
        );

        require(rate > 1e8, "invalid stWEMIX rate");

        return rate;
    }
}

function compareString(string memory a, string memory b) pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
}
