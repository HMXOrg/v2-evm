// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGasService {
  error GasService_NotEnoughCollateral();

  function collectExecutionFeeFromCollateral(address _primaryAccount, uint8 _subAccountId) external;
}
