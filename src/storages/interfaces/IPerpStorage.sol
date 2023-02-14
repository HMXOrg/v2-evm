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
    // LONG position
    uint256 longPositionSize;
    uint256 longAvgPrice;
    uint256 longFundingRate;
    uint256 longOpenInterest;
    // SHORT position
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
    uint256 shortFundingRate;
    uint256 shortOpenInterest;
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
    uint256 realizedPnl;
  }

  // getter
  function getPositionById(
    bytes32 _positionId
  ) external view returns (Position memory);

  // setter
  function updatePositionById(
    bytes32 _positionId,
    int256 _newPositionSizeE30,
    uint256 _newReserveValueE30,
    uint256 _newAvgPriceE30
  ) external returns (Position memory _position);
}
