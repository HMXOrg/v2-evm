// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPerpStorage {
  struct GlobalState {
    uint256 reserveValueE30; // accumulative of reserve value from all opening positions
    uint256 sumBorrowingRate;
    uint256 lastBorrowingTime;
  }

  struct GlobalAssetClass {
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
    int256 accumFundingLong;
    int256 accumFundingShort;
    int256 currentFundingRate;
    uint256 lastFundingTime;
  }

  // Trade position
  struct Position {
    address primaryAccount;
    int256 positionSizeE30; // LONG (+), SHORT(-) Position Size
    int256 realizedPnl;
    uint256 marketIndex;
    uint256 avgEntryPriceE30;
    uint256 entryBorrowingRate;
    int256 entryFundingRate;
    uint256 reserveValueE30; // Max Profit reserved in USD (9X of position collateral)
    uint256 lastIncreaseTimestamp; // To validate position lifetime
    uint256 openInterest;
    uint8 subAccountId;
  }

  /**
   * Getter
   */

  function getPositionBySubAccount(address _trader) external view returns (Position[] memory traderPositions);

  function getPositionById(bytes32 _positionId) external view returns (Position memory);

  function getGlobalMarketByIndex(uint256 __marketIndex) external view returns (GlobalMarket memory);

  function getGlobalAssetClassByIndex(uint256 _assetClassIndex) external view returns (GlobalAssetClass memory);

  function getGlobalState() external view returns (GlobalState memory);

  function getNumberOfSubAccountPosition(address _subAccount) external view returns (uint256);

  function getSubAccountFee(address _subAccount) external view returns (int256 fee);

  /**
   * Setter
   */

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

  function updateGlobalState(GlobalState memory _newGlobalState) external;

  function savePosition(address _subAccount, bytes32 _positionId, Position calldata position) external;

  function updateGlobalAssetClass(uint256 _assetClassIndex, GlobalAssetClass memory _newAssetClass) external;

  function updateSubAccountFee(address _subAccount, int256 fee) external;

  function updateGlobalMarket(uint256 _marketIndex, GlobalMarket memory _globalMarket) external;
}
