// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";

contract TradingStaking is ITradeServiceHook, Owned {
  error ITradingStaking_Forbidden();

  address public tradingStaking;
  address public tradeService;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert ITradingStaking_Forbidden();
    _;
  }

  constructor(address _tradingStaking, address _tradeService) {
    tradingStaking = _tradingStaking;
    tradeService = _tradeService;

    // Sanity checks
    ITradingStaking(tradingStaking).poolIdByMarketIndex(0);
    ITradeService(tradeService).configStorage();
  }

  function onIncreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) external onlyTradeService {
    ITradingStaking(tradingStaking).deposit(
      _primaryAccount,
      ITradingStaking(tradingStaking).poolIdByMarketIndex(_marketIndex),
      _sizeDelta
    );
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) external onlyTradeService {
    ITradingStaking(tradingStaking).withdraw(
      _primaryAccount,
      ITradingStaking(tradingStaking).poolIdByMarketIndex(_marketIndex),
      _sizeDelta
    );
  }
}
