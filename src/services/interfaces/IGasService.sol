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

  function collectExecutionFeeFromCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex
  ) external;
}
