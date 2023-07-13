// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IRebalanceHLPService {
  // error
  error RebalanceHLPService_OnlyWhitelisted();
  error RebalanceHLPService_AddressIsZero();
  error RebalanceHLPService_AmountIsZero();
  error RebalanceHLPService_HlpTvlDropExceedMin();
  error RebalanceHLPService_ParamsIsEmpty();

  /// @param token: the address of ERC20 token that will be converted into GLP.
  /// @param amount: the amount of token to convert to GLP.
  /// @param minAmountOutUSD: the minimum acceptable USD value of the GLP purchased
  /// @param minAmountOutGlp: the minimum acceptable GLP amount
  struct ExecuteParams {
    address token;
    uint256 amount;
    uint256 minAmountOutUSD;
    uint256 minAmountOutGlp;
  }

  function execute(ExecuteParams[] calldata params) external returns (uint256 receivedGlp);

  function setWhiteListExecutor(address executor, bool active) external;

  function setMinTvlBPS(uint16 minTvlBPS) external;
}
