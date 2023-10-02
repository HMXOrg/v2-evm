// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

interface ITradeHelper {
  /**
   * Errors
   */
  error ITradeHelper_TradingFeeCannotBeCovered();
  error ITradeHelper_BorrowingFeeCannotBeCovered();
  error ITradeHelper_FundingFeeCannotBeCovered();
  error ITradeHelper_UnrealizedPnlCannotBeCovered();
  error ITradeHelper_InvalidAddress();

  /**
   * State
   */

  function perpStorage() external view returns (address);

  function vaultStorage() external view returns (address);

  function configStorage() external view returns (address);

  /**
   * Functions
   */
  function reloadConfig() external;

  function updateBorrowingRate(uint8 _assetClassIndex) external;

  function updateFundingRate(uint256 _marketIndex) external;

  function increaseCollateral(
    bytes32 _positionId,
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    address _tpToken,
    uint256 _marketIndex
  ) external;

  function decreaseCollateral(
    bytes32 _positionId,
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator,
    uint256 _marketIndex
  ) external;

  function updateFeeStates(
    bytes32 _positionId,
    address _subAccount,
    IPerpStorage.Position memory _position,
    uint256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee);

  function settleAllFees(
    bytes32 _positionId,
    IPerpStorage.Position memory position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex
  ) external;
}
