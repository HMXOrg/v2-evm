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

  // mapping _marketIndex => globalPosition;
  struct GlobalMarket {
    // LONG position
    uint256 longPositionSize;
    uint256 longAvgPrice;
    uint256 longOpenInterest;
    // SHORT position
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
    uint256 shortOpenInterest;
    // funding rate
    uint256 fundingRate;
    uint256 lastFundingTime;
  }

  // Trade position
  struct Position {
    address primaryAccount;
    uint256 subAccountId;
    uint256 marketIndex;
    int256 positionSizeE30; // LONG (+), SHORT(-) Position Size
    uint256 avgEntryPriceE30;
    uint256 entryBorrowingRate;
    uint256 entryFundingRate;
    uint256 reserveValueE30; // Max Profit reserved in USD (9X of position collateral)
    uint256 lastIncreaseTimestamp; // To validate position lifetime
    uint256 realizedPnl;
    uint256 openInterest;
  }

  // getter
  function getPositionById(
    bytes32 _positionId
  ) external view returns (Position memory);

  function getGlobalMarketByIndex(
    uint256 __marketIndex
  ) external view returns (GlobalMarket memory);

  function getGlobalState() external view returns (GlobalState memory);

  function getNumberOfSubAccountPosition(
    address _subAccount
  ) external view returns (uint256);

  // setter
  function updatePositionById(
    bytes32 _positionId,
    int256 _newPositionSizeE30,
    uint256 _newReserveValueE30,
    uint256 _newAvgPriceE30,
    uint256 _newOpenInterest
  ) external returns (Position memory _position);

  function updateGlobalLongMarketById(
    uint256 __marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external;

  function updateGlobalShortMarketById(
    uint256 __marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external;

  // todo: update sumBorrowingRate, lastBorrowingTime
  function updateGlobalState(uint256 _newReserveValueE30) external;

  function savePosition(
    bytes32 _positionId,
    Position calldata position
  ) external;

  function updateReserveValue(uint256 newReserveValue) external;
}
