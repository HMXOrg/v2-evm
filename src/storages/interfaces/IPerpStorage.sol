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
    int256 sizeE30; // LONG (+), SHORT(-) Position Size
    uint256 avgPriceE30;
    uint256 entryBorrowingRate;
    uint256 entryFundingRate;
    uint256 reserveValueE30; // Max Profit reserved in USD (9X of position collateral)
    uint256 lastIncreaseTimestamp; // To validate position lifetime
    uint256 openInterest;
    uint256 realizedPnl;
  }

  function getPositionById(
    bytes32 _positionId
  ) external view returns (Position memory);

  function savePosition(
    bytes32 _positionId,
    Position calldata position
  ) external;

  function positionIndices(bytes32 key) external view returns (uint256);

  function subAccountPositionIndices(
    address _subAccount
  ) external view returns (uint256[] memory);

  function getGlobalState() external view returns (GlobalState memory);

  function updateReserveValue(uint256 newReserveValue) external;

  function updateGlobalLongMarketById(
    uint256 _marketId,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external;

  function updateGlobalShortMarketById(
    uint256 _marketId,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external;
}
