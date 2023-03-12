// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetAssetConfigs } from "@hmx-test/integration/06_BaseIntTest_SetAssetConfigs.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console } from "forge-std/console.sol";

abstract contract BaseIntTest_SetPLPTokens is BaseIntTest_SetAssetConfigs {
  constructor() {
    // Set PLP Tokens
    // @todo - GLP
    address[] memory _tokens = new address[](5);
    _tokens[0] = address(usdc);
    _tokens[1] = address(usdt);
    _tokens[2] = address(dai);
    _tokens[3] = address(weth);
    _tokens[4] = address(wbtc);

    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](_tokens.length);
    // @todo - integrate GLP, treat WBTC as GLP for now
    _plpTokenConfig[0] = _buildAcceptedPLPTokenConfig({
      _targetWeight: 0.05 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.95 * 1e18
    });
    _plpTokenConfig[1] = _buildNotAcceptedPLPTokenConfig();
    _plpTokenConfig[2] = _buildNotAcceptedPLPTokenConfig();
    _plpTokenConfig[3] = _buildNotAcceptedPLPTokenConfig();
    _plpTokenConfig[4] = _buildAcceptedPLPTokenConfig({
      _targetWeight: 0.95 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.05 * 1e18
    });

    configStorage.addOrUpdateAcceptedToken(_tokens, _plpTokenConfig);
  }

  function _buildAcceptedPLPTokenConfig(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff
  ) private pure returns (IConfigStorage.PLPTokenConfig memory _config) {
    _config.targetWeight = _targetWeight;
    _config.bufferLiquidity = _bufferLiquidity;
    _config.maxWeightDiff = _maxWeightDiff;
    _config.accepted = true;
    return _config;
  }

  function _buildNotAcceptedPLPTokenConfig() private pure returns (IConfigStorage.PLPTokenConfig memory _config) {
    return _config;
  }
}
