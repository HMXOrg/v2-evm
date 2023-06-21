// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest } from "./01_BaseIntTest.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetConfig is BaseIntTest {
  constructor() {
    // Set Minter
    hlpV2.setMinter(address(liquidityService), true);

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
    _setMinimumPositionSize();
  }

  function _setLiquidityConfig() private {
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 30, // 0.3%
        withdrawFeeRateBPS: 30, // 0.3%
        maxHLPUtilizationBPS: 8000, // 80%
        hlpTotalTokenWeight: 0,
        hlpSafetyBufferBPS: 2000, // 20%
        taxFeeRateBPS: 50, // 0.5%
        flashLoanFeeRateBPS: 0,
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
      baseBorrowingRate: 0.0001 * 1e18 // 0.01%
    });
    IConfigStorage.AssetClassConfig memory _equityConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.0002 * 1e18 // 0.02%
    });
    IConfigStorage.AssetClassConfig memory _forexConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.0003 * 1e18 // 0.03%
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

  function _setMinimumPositionSize() private {
    configStorage.setMinimumPositionSize(1e30);
  }
}
