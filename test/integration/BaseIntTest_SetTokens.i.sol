// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetOracle } from "@hmx-test/integration/BaseIntTest_SetOracle.i.sol";

import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";

import { console2 } from "forge-std/console2.sol";

abstract contract BaseIntTest_SetTokens is BaseIntTest_SetOracle {
  MockErc20 wbtc; // decimals 8
  MockErc20 usdc; // decimals 6
  MockErc20 usdt; // decimals 6
  MockErc20 dai; // decimals 18

  MockErc20 gmx; //decimals 18

  constructor() {
    wbtc = new MockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = new MockErc20("DAI Stablecoin", "DAI", 18);
    usdc = new MockErc20("USD Coin", "USDC", 6);
    usdt = new MockErc20("USD Tether", "USDT", 6);
    gmx = new MockErc20("GMX", "GMX", 18);
    plpV2 = IPLPv2(address(new MockErc20("PLPV2", "PLPv2", 18)));

    configStorage.setPLP(address(plpV2));

    _addAssetConfig(wethAssetId, address(weth), 18, false);

    _addAssetConfig(wbtcAssetId, address(wbtc), 8, false);

    _addAssetConfig(daiAssetId, address(dai), 18, true);

    _addAssetConfig(usdcAssetId, address(usdc), 6, true);

    _addAssetConfig(usdtAssetId, address(usdt), 6, true);

    _addAssetConfig(gmxAssetId, address(gmx), 18, true);
  }

  /// @notice to add asset config with some default value
  /// @param _assetId Asset's ID
  /// @param _token token address
  /// @param _decimals decimal of token
  /// @param _isStableCoin is stable coin
  function _addAssetConfig(bytes32 _assetId, address _token, uint8 _decimals, bool _isStableCoin) private {
    IConfigStorage.AssetConfig memory _assetConfig;

    _assetConfig.assetId = _assetId;
    _assetConfig.tokenAddress = _token;
    _assetConfig.decimals = _decimals;
    _assetConfig.isStableCoin = _isStableCoin;

    configStorage.setAssetConfig(_assetId, _assetConfig);
  }
}
