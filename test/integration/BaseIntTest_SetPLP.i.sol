// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetTokens } from "@hmx-test/integration/BaseIntTest_SetTokens.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetPLP is BaseIntTest_SetTokens {
  constructor() {
    // Assuming underlying of PLP is weth,wbtc,usdc,usdt,dai
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 0,
        withdrawFeeRateBPS: 0,
        maxPLPUtilizationBPS: 0.8 * 1e4,
        plpTotalTokenWeight: 0,
        plpSafetyBufferBPS: 0,
        taxFeeRateBPS: 0.005 * 1e4, // 0.5%
        flashLoanFeeRateBPS: 0,
        dynamicFeeEnabled: true,
        enabled: true
      })
    );

    _setupAcceptedToken();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  function _setupAcceptedToken() private {
    address[] memory _tokens = new address[](5);
    _tokens[0] = address(weth);
    _tokens[1] = address(wbtc);
    _tokens[2] = address(dai);
    _tokens[3] = address(usdc);
    _tokens[4] = address(usdt);

    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](_tokens.length);
    // TODO need to set real maxWeightDiff
    _plpTokenConfig[0] = _getPLPTokenConfigStruct(2e17, 0, 0, true);
    _plpTokenConfig[1] = _getPLPTokenConfigStruct(2e17, 0, 0, true);
    _plpTokenConfig[2] = _getPLPTokenConfigStruct(1e17, 0, 0, true);
    _plpTokenConfig[3] = _getPLPTokenConfigStruct(3e17, 0, 0, true);
    _plpTokenConfig[4] = _getPLPTokenConfigStruct(2e17, 0, 0, true);

    configStorage.addOrUpdateAcceptedToken(_tokens, _plpTokenConfig);
  }

  function _getPLPTokenConfigStruct(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff,
    bool _accepted
  ) private pure returns (IConfigStorage.PLPTokenConfig memory) {
    return
      IConfigStorage.PLPTokenConfig({
        targetWeight: _targetWeight,
        bufferLiquidity: _bufferLiquidity,
        maxWeightDiff: _maxWeightDiff,
        accepted: _accepted
      });
  }
}
