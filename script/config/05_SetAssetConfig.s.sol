// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPyth } from "lib/pyth-sdk-solidity/IPyth.sol";
import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";
import { IOracleAdapter } from "@hmx/oracle/interfaces/IOracleAdapter.sol";

contract SetAssetConfig is ConfigJsonRepo {
  bytes32 constant wethAssetId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 constant wbtcAssetId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 constant usdcAssetId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 constant usdtAssetId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 constant daiAssetId = 0x0000000000000000000000000000000000000000000000000000000000000005;
  bytes32 constant appleAssetId = 0x0000000000000000000000000000000000000000000000000000000000000006;
  bytes32 constant jpyAssetId = 0x0000000000000000000000000000000000000000000000000000000000000007;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    _addAssetConfig(wethAssetId, getJsonAddress(".tokens.weth"), 18, false);
    _addAssetConfig(wbtcAssetId, getJsonAddress(".tokens.wbtc"), 8, false);
    _addAssetConfig(daiAssetId, getJsonAddress(".tokens.dai"), 18, true);
    _addAssetConfig(usdcAssetId, getJsonAddress(".tokens.usdc"), 6, true);
    _addAssetConfig(usdtAssetId, getJsonAddress(".tokens.usdt"), 6, true);

    vm.stopBroadcast();
  }

  /// @notice to add asset config with some default value
  /// @param _assetId Asset's ID
  /// @param _token token address
  /// @param _decimals decimal of token
  /// @param _isStableCoin is stable coin
  function _addAssetConfig(bytes32 _assetId, address _token, uint8 _decimals, bool _isStableCoin) private {
    IConfigStorage.AssetConfig memory _assetConfig;
    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));

    _assetConfig.assetId = _assetId;
    _assetConfig.tokenAddress = _token;
    _assetConfig.decimals = _decimals;
    _assetConfig.isStableCoin = _isStableCoin;

    configStorage.setAssetConfig(_assetId, _assetConfig);
  }
}
