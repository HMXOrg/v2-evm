// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPerpStorage {
  // Collateral
  struct CollateralToken {
    address token;
    bytes32 assetId; // The pyth's asset address to set.
    uint256 collateralFactor; // Loan-To-Value
  }

  struct GlobalState {
    uint256 reserveValueE30; // accumulative of reserve value from all opening positions
    uint256 sumBorrowingRate;
    uint256 lastBorrowingTime;
  }

  // mapping marketId => globalPosition;
  struct GlobalMarket {
    uint256 globalLongSize; // (Long Open interest) in Amount
    uint256 globalShortSize; // (Short Open interest) in Amount
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
    int256 positionSizeE30; // LONG (+), SHORT(-) Position Size
    uint256 avgEntryPriceE30;
    uint256 entryBorrowingRate;
    uint256 entryFundingRate;
    uint256 reserveValueE30; // Max Profit reserved in USD (9X of position collateral)
    uint256 lastIncreaseTimestamp; // To validate position lifetime
    uint256 openInterest;
    uint256 realizedPnl;
  }

  function getGlobalMarkets(
    uint256 _key
  ) external view returns (GlobalMarket memory);
}
