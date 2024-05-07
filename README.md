# Shoebill Finance - Lending Protocol for LSDs



### Initial Exchange Rate

1 Token = 50 sbToken


### Contract Event 

Supply 

```
event AccrueInterest(uint cashPrior,  uint interestAccumulated,  uint borrowIndex,  uint totalBorrows );
event Mint(address minter, uint mintAmount, uint mintTokens /* sbToken Amount */ ); // 
event Transfer(address indexed from, address indexed to, uint256 amount);
```

Withdraw

```
event AccrueInterest(uint cashPrior,  uint interestAccumulated,  uint borrowIndex,  uint totalBorrows );
event Redeem(address redeemer, uint redeemAmount, uint redeemTokens /* sbToken Amount */ );
event Transfer(address indexed from, address indexed to, uint256 amount);
```

Borrow

```
event AccrueInterest(uint cashPrior,  uint interestAccumulated,  uint borrowIndex,  uint totalBorrows );
event Borrow(address borrower, uint borrowAmount,  uint accountBorrows,  uint totalBorrows);
```

Repay

```
event AccrueInterest(uint cashPrior,  uint interestAccumulated,  uint borrowIndex,  uint totalBorrows );
event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);
```

Liquidation

```
event AccrueInterest(uint cashPrior,  uint interestAccumulated,  uint borrowIndex,  uint totalBorrows );
event LiquidateBorrow(address liquidator, address borrower, uint256 repayAmount, address cTokenCollateral, uint256 seizeTokens);
event Transfer(address indexed from, address indexed to, uint256 amount); // to: liquidator
event Transfer(address indexed from, address indexed to, uint256 amount); // to: protocol
```

sbToken Transfer

```
event Transfer(address indexed from, address indexed to, uint256 amount);
```
