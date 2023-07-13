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

  /// @param _minUsdg: the minimum acceptable USD value of the GLP purchased
  /// @param _minGlp: the minimum acceptable GLP amount
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
