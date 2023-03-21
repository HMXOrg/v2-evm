// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract SetConfig is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    PLPv2 plpV2 = PLPv2(getJsonAddress(".tokens.plp"));
    plpV2.setMinter(getJsonAddress(".services.liquidity"), true);

    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));

    _setLiquidityConfig(configStorage);
    _setUpSwapConfig(configStorage);
    _setUpTradingConfig(configStorage);
    _setUpAssetClassConfigs(configStorage);
    _setUpLiquidationConfig(configStorage);

    vm.stopBroadcast();
  }

  function _setLiquidityConfig(IConfigStorage configStorage) private {
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

  function _setUpSwapConfig(IConfigStorage configStorage) private {
    configStorage.setSwapConfig(IConfigStorage.SwapConfig({ stablecoinSwapFeeRateBPS: 0, swapFeeRateBPS: 0 }));
  }

  function _setUpTradingConfig(IConfigStorage configStorage) private {
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({
        fundingInterval: 1, // second
        devFeeRateBPS: 1500, // 15%
        minProfitDuration: 15, // second
        maxPosition: 10
      })
    );
  }

  function _setUpAssetClassConfigs(IConfigStorage configStorage) private {
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.00000003 * 1e18 // 0.01% per hour
    });
    IConfigStorage.AssetClassConfig memory _equityConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.00000006 * 1e18 // 0.02% per hour
    });
    IConfigStorage.AssetClassConfig memory _forexConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.00000008 * 1e18 // 0.03% per hour
    });

    configStorage.addAssetClassConfig(_cryptoConfig);
    configStorage.addAssetClassConfig(_equityConfig);
    configStorage.addAssetClassConfig(_forexConfig);
  }

  function _setUpLiquidationConfig(IConfigStorage configStorage) private {
    IConfigStorage.LiquidationConfig memory _liquidationConfig = IConfigStorage.LiquidationConfig({
      liquidationFeeUSDE30: 5 * 1e30
    });

    configStorage.setLiquidationConfig(_liquidationConfig);
  }
}
