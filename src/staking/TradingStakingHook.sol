// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";

contract TradingStakingHook is ITradeServiceHook, OwnableUpgradeable {
  error TradingStakingHook_Forbidden();

  address public tradingStaking;
  address public tradeService;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert TradingStakingHook_Forbidden();
    _;
  }

  function initialize(address _tradingStaking, address _tradeService) external initializer {
    OwnableUpgradeable.__Ownable_init();

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
    ITradingStaking(tradingStaking).deposit(_primaryAccount, _marketIndex, _sizeDelta / 1e12);
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    ITradingStaking(tradingStaking).withdraw(_primaryAccount, _marketIndex, _sizeDelta / 1e12);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
