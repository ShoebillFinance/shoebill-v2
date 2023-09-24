// SPDX-License-Identifier: MIT

pragma solidity =0.8.16;

import "./BasicLens.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../CErc20.sol";
import "../JumpRateModelV4.sol";

contract ProtocolLens is BasicLens {
    string public constant mainSymbol = "WEMIX";
    string public constant mainCTokenSymbol = "sbWEMIX";

    struct CTokenInfo {
        address underlyingAssetAddress;
        uint256 underlyingDecimals;
        address contractAddress;
        uint256 poolBalance;
        string underlyingSymbol;
        string symbol;
        uint8 decimals;
        bool isNative;
        uint256 supplyRatePerBlock;
        uint256 borrowRatePerBlock;
        uint256 totalSupply;
        uint256 totalBorrows;
        uint256 collateralFactor;
        uint256 oraclePrice;
        uint256 totalReserves;
        uint256 cash;
        uint256 reserveFactorMantissa;
        uint256 exchangeRateCurrent;
        uint256 multiplierPerBlock;
        uint256 kink;
        uint256 baseRatePerBlock;
        uint256 jumpMultiplierPerBlock;
        bool isMintPaused;
        bool isBorrowPaused;
        bool isSeizePaused;
        bool isTransferPaused;
        uint256 borrowCap;
        uint256 supplyCap;
    }

    // returns CTokenInfo
    // call using callStatic to avoid gas fee
    function getCTokenInfo(
        CToken cToken,
        Comptroller comptroller
    ) public returns (CTokenInfo memory) {
        address underlyingAssetAddress;
        uint256 underlyingDecimals;
        bool isNative = compareStrings(cToken.symbol(), mainCTokenSymbol);
        CTokenInfo memory cTokenInfo;

        if (isNative) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
            cTokenInfo.underlyingSymbol = mainSymbol;
        } else {
            CErc20 cErc20 = CErc20(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
            cTokenInfo.underlyingSymbol = EIP20Interface(cErc20.underlying())
                .symbol();
        }

        cTokenInfo.isNative = isNative;

        address contractAddress = address(cToken);

        cTokenInfo.underlyingAssetAddress = underlyingAssetAddress;
        cTokenInfo.underlyingDecimals = underlyingDecimals;
        cTokenInfo.contractAddress = contractAddress;
        cTokenInfo.poolBalance = isNative
            ? contractAddress.balance
            : IERC20(underlyingAssetAddress).balanceOf(contractAddress);
        cTokenInfo.symbol = cToken.symbol();
        cTokenInfo.decimals = cToken.decimals();
        cTokenInfo.supplyRatePerBlock = cToken.supplyRatePerBlock();
        cTokenInfo.borrowRatePerBlock = cToken.borrowRatePerBlock();
        cTokenInfo.totalSupply = cToken.totalSupply();
        cTokenInfo.totalBorrows = cToken.totalBorrows();
        (, cTokenInfo.collateralFactor, ) = comptroller.markets(
            contractAddress
        );

        cTokenInfo.oraclePrice = getOraclePrice(cToken, comptroller);

        cTokenInfo.totalReserves = cToken.totalReserves();
        cTokenInfo.cash = cToken.getCash();
        cTokenInfo.reserveFactorMantissa = cToken.reserveFactorMantissa();
        cTokenInfo.exchangeRateCurrent = cToken.exchangeRateCurrent();

        JumpRateModelV4 interestRateModel = JumpRateModelV4(
            address(cToken.interestRateModel())
        );

        cTokenInfo.multiplierPerBlock = interestRateModel.multiplierPerBlock();
        cTokenInfo.kink = interestRateModel.kink();
        cTokenInfo.baseRatePerBlock = interestRateModel.baseRatePerBlock();
        cTokenInfo.jumpMultiplierPerBlock = interestRateModel
            .jumpMultiplierPerBlock();

        cTokenInfo.isMintPaused = comptroller.mintGuardianPaused(
            contractAddress
        );
        cTokenInfo.isBorrowPaused = comptroller.borrowGuardianPaused(
            contractAddress
        );
        cTokenInfo.isSeizePaused = comptroller.seizeGuardianPaused();
        cTokenInfo.isTransferPaused = comptroller.transferGuardianPaused();

        cTokenInfo.borrowCap = comptroller.borrowCaps(contractAddress);
        cTokenInfo.supplyCap = comptroller.supplyCaps(contractAddress);
        return cTokenInfo;
    }

    struct AccountInfo {
        uint256 mySuppliedBalance;
        uint256 myBorrowedBalance;
        uint256 myCTokenBalance;
        // uint256 mySupplyPrincipalBalance;
        // uint256 myBorrowPrincipalBalance;
        uint256 myRealTokenBalance;
        // uint256 incentiveTokenSupplierIndex;
        // uint256 incentiveTokenBorrowerIndex;
        uint256 allowance;
    }

    // returns AccountInfo
    function getAccountInfo(
        CToken cToken,
        address payable account
    ) public returns (AccountInfo memory) {
        AccountInfo memory accountInfo;

        address underlyingAssetAddress;
        address contractAddress = address(cToken);

        bool isNative = compareStrings(cToken.symbol(), mainCTokenSymbol);
        if (isNative) {
            underlyingAssetAddress = address(0);
            accountInfo.allowance = type(uint256).max;
        } else {
            CErc20 cErc20 = CErc20(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            accountInfo.allowance = EIP20Interface(underlyingAssetAddress)
                .allowance(account, contractAddress);
        }

        accountInfo.mySuppliedBalance = cToken.balanceOfUnderlying(account);
        accountInfo.myBorrowedBalance = cToken.borrowBalanceCurrent(account);
        accountInfo.myCTokenBalance = cToken.balanceOf(account);
        // accountInfo.mySupplyPrincipalBalance = cToken.supplyPrincipal(account);
        // accountInfo.myBorrowPrincipalBalance = cToken.borrowPrincipal(account);
        accountInfo.myRealTokenBalance = isNative
            ? account.balance
            : IERC20(underlyingAssetAddress).balanceOf(account);
        // accountInfo.incentiveTokenSupplierIndex = controller
        //     .incentiveTokenSupplierIndex(contractAddress, account);
        // accountInfo.incentiveTokenBorrowerIndex = controller
        //     .incentiveTokenBorrowerIndex(contractAddress, account);

        return accountInfo;
    }

    // get cToken's underlying price
    function getOraclePrice(
        CToken cToken,
        Comptroller comptroller
    ) public view returns (uint256) {
        PriceOracle oracle = comptroller.oracle();

        return oracle.getPrice(cToken);
    }

    struct CTokenMetaData {
        CTokenInfo cTokenInfo;
        AccountInfo accountInfo;
    }

    function cTokenMetaDataList(
        Comptroller comptroller
    ) external returns (CTokenMetaData[] memory) {
        CToken[] memory allMarkets = comptroller.getAllMarkets();
        CTokenMetaData[] memory result = new CTokenMetaData[](
            allMarkets.length
        );

        for (uint256 i = 0; i < allMarkets.length; i++) {
            result[i].cTokenInfo = getCTokenInfo(allMarkets[i], comptroller);
        }
        return result;
    }

    function cTokenMetaDataListAuth(
        address payable account,
        Comptroller comptroller
    ) external returns (CTokenMetaData[] memory) {
        CToken[] memory allMarkets = comptroller.getAllMarkets();
        CTokenMetaData[] memory result = new CTokenMetaData[](
            allMarkets.length
        );

        for (uint256 i = 0; i < allMarkets.length; i++) {
            result[i].cTokenInfo = getCTokenInfo(allMarkets[i], comptroller);
            result[i].accountInfo = getAccountInfo(allMarkets[i], account);
        }
        return result;
    }

    /* internal functions  */
    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
