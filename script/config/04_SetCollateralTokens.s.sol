// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";
import { IOracleAdapter } from "@hmx/oracle/interfaces/IOracleAdapter.sol";

contract SetCollateralTokens is ConfigJsonRepo {
  // Arbitrum Goerli Price Feed IDs (https://pyth.network/developers/price-feed-ids#pyth-evm-testnet)
  bytes32 internal constant wethPriceId = 0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6;
  bytes32 internal constant wbtcPriceId = 0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b;
  bytes32 internal constant usdcPriceId = 0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722;
  bytes32 internal constant usdtPriceId = 0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588;
  bytes32 internal constant daiPriceId = 0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412;
  bytes32 internal constant applePriceId = 0xafcc9a5bb5eefd55e12b6f0b4c8e6bccf72b785134ee232a5d175afd082e8832;
  bytes32 internal constant jpyPriceId = 0x20a938f54b68f1f2ef18ea0328f6dd0747f8ea11486d22b021e83a900be89776;

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

    // @todo - GLP
    // collateralFactorBPS = 80%
    _addCollateralConfig(wethAssetId, 8000, true, address(0));
    // collateralFactorBPS = 80%
    _addCollateralConfig(wbtcAssetId, 8000, true, address(0));
    // collateralFactorBPS = 100%
    _addCollateralConfig(daiAssetId, 10000, true, address(0));
    // collateralFactorBPS = 100%
    _addCollateralConfig(usdcAssetId, 10000, true, address(0));
    // collateralFactorBPS = 100%
    _addCollateralConfig(usdtAssetId, 10000, true, address(0));

    vm.stopBroadcast();
  }

  /// @notice to add collateral config with some default value
  /// @param _assetId Asset's ID
  /// @param _collateralFactorBPS token reliability factor to calculate buying power, 1e4 = 100%
  /// @param _isAccepted accepted to deposit as collateral
  /// @param _settleStrategy determine token will be settled for NON PLP collateral, e.g. aUSDC redeemed as USDC
  function _addCollateralConfig(
    bytes32 _assetId,
    uint32 _collateralFactorBPS,
    bool _isAccepted,
    address _settleStrategy
  ) private {
    IConfigStorage.CollateralTokenConfig memory _collatTokenConfig;
    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));

    _collatTokenConfig.collateralFactorBPS = _collateralFactorBPS;
    _collatTokenConfig.accepted = _isAccepted;
    _collatTokenConfig.settleStrategy = _settleStrategy;

    configStorage.setCollateralTokenConfig(_assetId, _collatTokenConfig);
  }
}
