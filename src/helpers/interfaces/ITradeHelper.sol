// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

interface ITradeHelper {
  error ITradeHelper_TradingFeeCannotBeCovered();
  error ITradeHelper_BorrowingFeeCannotBeCovered();
  error ITradeHelper_FundingFeeCannotBeCovered();

  function reloadConfig() external;

  function updateBorrowingRate(uint8 _assetClassIndex, uint256 _limitPriceE30, bytes32 _limitAssetId) external;

  function updateFundingRate(uint256 _marketIndex, uint256 _limitPriceE30) external;

  // function collectMarginFee(
  //   address _subAccount,
  //   uint256 _absSizeDelta,
  //   uint8 _assetClassIndex,
  //   uint256 _reservedValue,
  //   uint256 _entryBorrowingRate,
  //   uint32 _positionFeeBPS
  // ) external;

  // function collectFundingFee(
  //   address _subAccount,
  //   uint8 _assetClassIndex,
  //   uint256 _marketIndex,
  //   int256 _positionSizeE30,
  //   int256 _entryFundingRate
  // ) external;

  // function settleMarginFee(address _subAccount) external;

  // function settleFundingFee(address _subAccount, uint256 _limitPriceE30, bytes32 _limitAssetId) external;

  function settleAllFees(
    PerpStorage.Position memory position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external;
}
