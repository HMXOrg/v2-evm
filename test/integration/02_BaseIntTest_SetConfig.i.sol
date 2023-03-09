// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest } from "./01_BaseIntTest.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetConfig is BaseIntTest {
  constructor() {
    // Setup Liquidity config for global used
    _setLiquidityConfig();
    // Setup Swap config for global used
    _setUpSwapConfig();
    // Setup Trading config for global used
    _setUpTradingConfig();
    // Setup Asset Class config for global used
    _setUpAssetClassConfigs();
    // Setup Liquidation config for global used
    _setUpLiquidationConfig();
  }

  function _setLiquidityConfig() private {
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 0,
        withdrawFeeRateBPS: 0,
        maxPLPUtilizationBPS: 0.8 * 1e4,
        plpTotalTokenWeight: 0,
        plpSafetyBufferBPS: 0,
        taxFeeRateBPS: 0.005 * 1e4, // 0.5%
        flashLoanFeeRateBPS: 0,
        dynamicFeeEnabled: false,
        enabled: true
      })
    );
  }

  function _setUpSwapConfig() private {
    configStorage.setSwapConfig(IConfigStorage.SwapConfig({ stablecoinSwapFeeRateBPS: 0, swapFeeRateBPS: 0 }));
  }

  function _setUpTradingConfig() private {
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({
        fundingInterval: 1,
        devFeeRateBPS: 0.15 * 1e4,
        minProfitDuration: 0,
        maxPosition: 5
      })
    );
  }

  function _setUpAssetClassConfigs() private {
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRateBPS: 0.0001 * 1e4 // 0.01%
    });
    IConfigStorage.AssetClassConfig memory _forexConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRateBPS: 0.0002 * 1e4 // 0.02%
    });

    configStorage.addAssetClassConfig(_cryptoConfig);
    configStorage.addAssetClassConfig(_forexConfig);
  }

  function _setUpLiquidationConfig() private {
    IConfigStorage.LiquidationConfig memory _liquidationConfig = IConfigStorage.LiquidationConfig({
      liquidationFeeUSDE30: 5 * 1e30
    });

    configStorage.setLiquidationConfig(_liquidationConfig);
  }
}
