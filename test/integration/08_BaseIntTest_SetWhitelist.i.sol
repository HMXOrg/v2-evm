// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetPLPTokens } from "@hmx-test/integration/07_BaseIntTest_SetPLPTokens.i.sol";

abstract contract BaseIntTest_SetWhitelist is BaseIntTest_SetPLPTokens {
  constructor() {
    // Set order executors
    limitTradeHandler.setOrderExecutor(ORDER_EXECUTOR, true);
    liquidityHandler.setOrderExecutor(ORDER_EXECUTOR, true);

    // Set Cross margin executors
    configStorage.setServiceExecutor(address(crossMarginService), address(crossMarginHandler), true);

    // Set Liquidity service executors
    configStorage.setServiceExecutor(address(liquidityService), address(liquidityHandler), true);

    // Set Liquidation service executors
    configStorage.setServiceExecutor(address(liquidationService), address(botHandler), true);

    // Set Trade service executors
    configStorage.setServiceExecutor(address(tradeService), address(limitTradeHandler), true);
    configStorage.setServiceExecutor(address(tradeService), address(marketTradeHandler), true);
    configStorage.setServiceExecutor(address(tradeService), address(botHandler), true);

    pyth.setUpdater(address(crossMarginHandler), true);
    pyth.setUpdater(address(liquidityHandler), true);
    pyth.setUpdater(address(limitTradeHandler), true);
    pyth.setUpdater(address(marketTradeHandler), true);
  }
}
