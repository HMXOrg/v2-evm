// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

interface ITradeHelper {
  error ITradeHelper_TradingFeeCannotBeCovered();
  error ITradeHelper_BorrowingFeeCannotBeCovered();
  error ITradeHelper_FundingFeeCannotBeCovered();
  error ITradeHelper_InvalidAddress();

  function reloadConfig() external;

  function updateBorrowingRate(uint8 _assetClassIndex) external;

  function updateFundingRate(uint256 _marketIndex) external;

  function settleAllFees(
    PerpStorage.Position memory position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external;
}
