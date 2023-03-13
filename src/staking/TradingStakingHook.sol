// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";

contract TradingStakingHook is ITradeServiceHook, Owned {
  error TradingStakingHook_Forbidden();

  address public tradingStaking;
  address public tradeService;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert TradingStakingHook_Forbidden();
    _;
  }

  constructor(address _tradingStaking, address _tradeService) {
    tradingStaking = _tradingStaking;
    tradeService = _tradeService;

    // Sanity checks
    ITradingStaking(tradingStaking).isRewarder(address(0));
    ITradeService(tradeService).configStorage();
  }

  function onIncreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    ITradingStaking(tradingStaking).deposit(_primaryAccount, _marketIndex, _sizeDelta);
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    ITradingStaking(tradingStaking).withdraw(_primaryAccount, _marketIndex, _sizeDelta);
  }
}
