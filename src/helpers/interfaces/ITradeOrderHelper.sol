// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IIntentHandler } from "@hmx/handlers/interfaces/IIntentHandler.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

interface ITradeOrderHelper {
  /**
   * Errors
   */
  error TradeOrderHelper_MaxTradeSize();
  error TradeOrderHelper_MaxPositionSize();
  error TradeOrderHelper_PriceSlippage();
  error TradeOrderHelper_MarketIsClosed();
  error TradeOrderHelper_InvalidPriceForExecution();
  error TradeOrderHelper_NotWhiteListed();
  error TradeOrderHelper_OrderStale();

  /**
   * Event
   */
  event LogSetLimit(uint256 _marketIndex, uint256 _positionSizeLimitOf, uint256 _tradeSizeLimitOf);
  event LogSetWhitelistedCaller(address oldWhitelistedCaller, address newWhitelistedCaller);

  /**
   * State
   */

  function perpStorage() external view returns (PerpStorage);

  function tradeService() external view returns (TradeService);

  function configStorage() external view returns (ConfigStorage);

  function whitelistedCaller() external view returns (address);

  /**
   * Functions
   */
  function execute(IIntentHandler.ExecuteTradeOrderVars memory vars) external;

  function setLimit(
    uint256[] calldata _marketIndexes,
    uint256[] calldata _positionSizeLimits,
    uint256[] calldata _tradeSizeLimits
  ) external;

  function setWhitelistedCaller(address _whitelistedCaller) external;
}
