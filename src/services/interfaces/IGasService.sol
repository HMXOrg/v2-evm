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
  event LogSetExecutionFeeSubsidizationConfig(bool isGasSubsidization, uint256 waivedExecutionFeeTradeSize);
  event LogSubsidizeExecutionFee(address subAccount, uint256 marketIndex, uint256 executionFeeUsd);
  event LogAdjustSubsidizedExecutionFeeValue(uint256 previousValue, uint256 newValue, int256 delta);

  function collectExecutionFeeFromCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _absSizeDelta
  ) external;

  function setExecutionFeeSubsidizationConfig(
    bool _isExecutionFeeSubsidization,
    uint256 _waivedExecutionFeeTradeSize
  ) external;

  function adjustSubsidizedExecutionFeeValue(int256 deltaValueE30) external;

  function subsidizedExecutionFeeValue() external view returns (uint256);

  function waivedExecutionFeeTradeSize() external view returns (uint256);
}
