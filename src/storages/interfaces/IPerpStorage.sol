// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPerpStorage {
  // Collateral
  struct CollateralToken {
    address token;
    bytes32 assetId; // The pyth's asset address to set.
    uint256 collateralFactor; // Loan-To-Value
  }

  struct Global {
    uint256 reserveValueE30;
    uint256 sumBorrowingRate;
    uint256 lastBorrowingTime;
  }

  // mapping marketId => globalPosition;
  struct GlobalMarket {
    uint256 globalLongSize; // (Open interest) in Amount
    uint256 globalShortSize; // (Open interest) in Amount
    uint256 globalLongAvgPrice;
    uint256 globalShortAvgPrice;
    uint256 globalLongFundingRate;
    uint256 globalShortFundingRate;
    uint256 lastFundingTime;
  }

  // Trade position
  struct Position {
    address primaryAccount;
    uint8 subAccount;
    uint256 marketIndex;
    int256 positionSizeE30; // LONG (+), SHORT(-) Size
    uint256 avgEntryPriceE30;
    uint256 entryBorrowingRate;
    uint256 entryFundingRate;
    uint256 reserveValueE30; // Max Profit in USD (9X of collateral)
    uint256 lastIncreaseTime; // To calculate minimum opening time of position
    uint256 openInterest;
    uint256 realizedPnl; // for Partial Close
  }
}
