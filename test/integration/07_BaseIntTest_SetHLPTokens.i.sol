// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_SetAssetConfigs } from "@hmx-test/integration/06_BaseIntTest_SetAssetConfigs.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetHLPTokens is BaseIntTest_SetAssetConfigs {
  constructor() {
    // Set HLP Tokens
    // @todo - GLP
    address[] memory _tokens = new address[](5);
    _tokens[0] = address(usdc);
    _tokens[1] = address(usdt);
    _tokens[2] = address(dai);
    _tokens[3] = address(weth);
    _tokens[4] = address(wbtc);

    IConfigStorage.HLPTokenConfig[] memory _hlpTokenConfig = new IConfigStorage.HLPTokenConfig[](_tokens.length);
    // @todo - integrate GLP, treat WBTC as GLP for now
    _hlpTokenConfig[0] = _buildAcceptedHLPTokenConfig({
      _targetWeight: 0.05 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.95 * 1e18
    });
    _hlpTokenConfig[1] = _buildNotAcceptedHLPTokenConfig();
    _hlpTokenConfig[2] = _buildNotAcceptedHLPTokenConfig();
    _hlpTokenConfig[3] = _buildNotAcceptedHLPTokenConfig();
    _hlpTokenConfig[4] = _buildAcceptedHLPTokenConfig({
      _targetWeight: 0.95 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.05 * 1e18
    });

    configStorage.addOrUpdateAcceptedToken(_tokens, _hlpTokenConfig);
  }

  function _buildAcceptedHLPTokenConfig(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff
  ) private pure returns (IConfigStorage.HLPTokenConfig memory _config) {
    _config.targetWeight = _targetWeight;
    _config.bufferLiquidity = _bufferLiquidity;
    _config.maxWeightDiff = _maxWeightDiff;
    _config.accepted = true;
    return _config;
  }

  function _buildNotAcceptedHLPTokenConfig() private pure returns (IConfigStorage.HLPTokenConfig memory _config) {
    return _config;
  }
}
