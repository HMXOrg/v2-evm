// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";

contract TradingStakingHook is ITradeServiceHook, Owned {
  error ITradingStaking_Forbidden();
  error ITradingStaking_WrongPool();

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
    if (ITradingStaking(tradingStaking).isAcceptedMarketIndex(_marketIndex)) {
      ITradingStaking(tradingStaking).deposit(
        _primaryAccount,
        ITradingStaking(tradingStaking).poolIdByMarketIndex(_marketIndex),
        _sizeDelta
      );
    } else {
      revert ITradingStaking_WrongPool();
    }
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) external onlyTradeService {
    if (ITradingStaking(tradingStaking).isAcceptedMarketIndex(_marketIndex)) {
      ITradingStaking(tradingStaking).withdraw(
        _primaryAccount,
        ITradingStaking(tradingStaking).poolIdByMarketIndex(_marketIndex),
        _sizeDelta
      );
    } else {
      revert ITradingStaking_WrongPool();
    }
  }
}
