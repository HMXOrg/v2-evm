// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IWithdrawGlpStrategy {
  // error
  error WithdrawGlpStrategy_OnlyWhitelisted();
  error WithdrawGlpStrategy_AddressIsZero();
  error WithdrawGlpStrategy_AmountIsZero();
  error WithdrawGlpStrategy_ParamsIsEmpty();
  error WithdrawGlpStrategy_HlpTvlDropExceedMin();

  /// @param _minUsdg: the minimum acceptable USD value of the GLP purchased
  /// @param _minGlp: the minimum acceptable GLP amount
  struct ExecuteParams {
    address token;
    uint256 glpAmount;
    uint256 minOut;
  }

  function execute(ExecuteParams[] calldata params) external;

  function setWhiteListExecutor(address executor, bool active) external;
}
