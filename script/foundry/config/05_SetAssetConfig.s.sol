// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { HLP } from "@hmx/contracts/HLP.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";

contract SetAssetConfig is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    bytes32[] memory _assetIds = new bytes32[](6);
    _assetIds[0] = wethAssetId;
    _assetIds[1] = wbtcAssetId;
    _assetIds[2] = daiAssetId;
    _assetIds[3] = usdcAssetId;
    _assetIds[4] = usdtAssetId;
    _assetIds[5] = glpAssetId;

    IConfigStorage.AssetConfig[] memory _newConfigs = new IConfigStorage.AssetConfig[](6);
    _newConfigs[0] = IConfigStorage.AssetConfig({
      assetId: wethAssetId,
      tokenAddress: getJsonAddress(".tokens.weth"),
      decimals: 18,
      isStableCoin: false
    });
    _newConfigs[1] = IConfigStorage.AssetConfig({
      assetId: wbtcAssetId,
      tokenAddress: getJsonAddress(".tokens.wbtc"),
      decimals: 8,
      isStableCoin: false
    });
    _newConfigs[2] = IConfigStorage.AssetConfig({
      assetId: daiAssetId,
      tokenAddress: getJsonAddress(".tokens.dai"),
      decimals: 18,
      isStableCoin: false
    });
    _newConfigs[3] = IConfigStorage.AssetConfig({
      assetId: usdcAssetId,
      tokenAddress: getJsonAddress(".tokens.usdc"),
      decimals: 6,
      isStableCoin: false
    });
    _newConfigs[4] = IConfigStorage.AssetConfig({
      assetId: usdtAssetId,
      tokenAddress: getJsonAddress(".tokens.usdt"),
      decimals: 6,
      isStableCoin: false
    });
    _newConfigs[5] = IConfigStorage.AssetConfig({
      assetId: glpAssetId,
      tokenAddress: getJsonAddress(".tokens.sglp"),
      decimals: 18,
      isStableCoin: false
    });
    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));
    configStorage.setAssetConfigs(_assetIds, _newConfigs);
    vm.stopBroadcast();
  }
}
