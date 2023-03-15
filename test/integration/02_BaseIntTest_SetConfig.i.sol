// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest } from "./01_BaseIntTest.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetConfig is BaseIntTest {
  constructor() {
    // Set Minter
    plpV2.setMinter(address(liquidityService), true);

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

    _setUpPnlFactor();
  }

  function _setLiquidityConfig() private {
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 30, // 0.3%
        withdrawFeeRateBPS: 30, // 0.3%
        maxPLPUtilizationBPS: 8000, // 80%
        plpTotalTokenWeight: 0,
        plpSafetyBufferBPS: 2000, // 20%
        taxFeeRateBPS: 50, // 0.5%
        flashLoanFeeRateBPS: 0, // @todo - TBD
        dynamicFeeEnabled: true,
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
        fundingInterval: 1, // second
        devFeeRateBPS: 1500, // 15%
        minProfitDuration: 15, // second
        maxPosition: 10
      })
    );
  }

  function _setUpAssetClassConfigs() private {
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRateBPS: 1 // 0.01%
    });
    IConfigStorage.AssetClassConfig memory _equityConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRateBPS: 2 // 0.02%
    });
    IConfigStorage.AssetClassConfig memory _forexConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRateBPS: 3 // 0.03%
    });

    configStorage.addAssetClassConfig(_cryptoConfig);
    configStorage.addAssetClassConfig(_equityConfig);
    configStorage.addAssetClassConfig(_forexConfig);
  }

  function _setUpLiquidationConfig() private {
    IConfigStorage.LiquidationConfig memory _liquidationConfig = IConfigStorage.LiquidationConfig({
      liquidationFeeUSDE30: 5 * 1e30
    });

    configStorage.setLiquidationConfig(_liquidationConfig);
  }

  function _setUpPnlFactor() private {
    configStorage.setPnlFactor(0.8 * 1e4);
  }
}
