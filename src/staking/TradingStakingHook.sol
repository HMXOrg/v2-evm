// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
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
    ITradingStaking ts = ITradingStaking(tradingStaking);
    if (ts.isMarketIndex(_marketIndex)) {
      ts.deposit(_primaryAccount, _marketIndex, _sizeDelta / 1e12);
    }
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    ITradingStaking ts = ITradingStaking(tradingStaking);
    uint256 amountToWithdraw = _sizeDelta / 1e12;
    uint256 userTokenAmount = ts.getUserTokenAmount(_marketIndex, _primaryAccount);
    if (userTokenAmount >= amountToWithdraw) {
      ts.withdraw(_primaryAccount, _marketIndex, amountToWithdraw);
    } else if (userTokenAmount > 0) {
      ts.withdraw(_primaryAccount, _marketIndex, userTokenAmount);
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
