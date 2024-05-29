// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGasService {
  error GasService_NotEnoughCollateral();

  event LogSetParams(uint256 executionFeeInUsd, address executionFeeTreasury);
  event LogCollectExecutionFeeValue(address subAccount, uint256 marketIndex, uint256 executionFeeUsd);
  event LogCollectExecutionFeeAmount(
    address subAccount,
    uint256 marketIndex,
    address token,
    uint256 executionFeeAmount
  );
  event LogSetWaviedExecutionFeeMinTradeSize(uint256 waivedExecutionFeeTradeSize);
  event LogSubsidizeExecutionFee(address subAccount, uint256 marketIndex, uint256 executionFeeUsd);
  event LogAdjustSubsidizedExecutionFeeValue(uint256 previousValue, uint256 newValue, int256 delta);
  event LogSetGasTokenAssetId(bytes32 gasTokenAssetId);

  function collectExecutionFeeFromCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _absSizeDelta,
    uint256 _gasBefore
  ) external;

  function setWaviedExecutionFeeMinTradeSize(uint256 _waviedExecutionFeeMinTradeSize) external;

  function adjustSubsidizedExecutionFeeValue(int256 deltaValueE30) external;

  function subsidizedExecutionFeeValue() external view returns (uint256);

  function waviedExecutionFeeMinTradeSize() external view returns (uint256);

  function setGasTokenAssetId(bytes32 _gasTokenAssetId) external;
}
