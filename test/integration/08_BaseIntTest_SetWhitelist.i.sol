// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseIntTest_SetHLPTokens } from "@hmx-test/integration/07_BaseIntTest_SetHLPTokens.i.sol";

abstract contract BaseIntTest_SetWhitelist is BaseIntTest_SetHLPTokens {
  constructor() {
    // Set order executors
    limitTradeHandler.setOrderExecutor(ORDER_EXECUTOR, true);
    liquidityHandler.setOrderExecutor(ORDER_EXECUTOR, true);

    address[] memory _contractAddresses = new address[](6);
    address[] memory _executorAddresses = new address[](6);
    bool[] memory _isServiceExecutors = new bool[](6);
    // Set Cross margin executors
    _contractAddresses[0] = address(crossMarginService);
    _executorAddresses[0] = address(crossMarginHandler);
    _isServiceExecutors[0] = true;

    // Set Liquidity service executors
    _contractAddresses[1] = address(liquidityService);
    _executorAddresses[1] = address(liquidityHandler);
    _isServiceExecutors[1] = true;

    // Set Liquidation service executors
    _contractAddresses[2] = address(liquidationService);
    _executorAddresses[2] = address(botHandler);
    _isServiceExecutors[2] = true;

    // Set Trade service executors
    _contractAddresses[3] = address(tradeService);
    _executorAddresses[3] = address(limitTradeHandler);
    _isServiceExecutors[3] = true;

    _contractAddresses[4] = address(tradeService);
    _executorAddresses[4] = address(marketTradeHandler);
    _isServiceExecutors[4] = true;

    _contractAddresses[5] = address(tradeService);
    _executorAddresses[5] = address(botHandler);
    _isServiceExecutors[5] = true;

    configStorage.setServiceExecutors(_contractAddresses, _executorAddresses, _isServiceExecutors);

    pyth.setUpdater(address(crossMarginHandler), true);
    pyth.setUpdater(address(liquidityHandler), true);
    pyth.setUpdater(address(limitTradeHandler), true);
    pyth.setUpdater(address(marketTradeHandler), true);
    pyth.setUpdater(address(botHandler), true);
  }
}
