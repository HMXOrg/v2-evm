// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetPLPTokens } from "@hmx-test/integration/07_BaseIntTest_SetPLPTokens.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console } from "forge-std/console.sol";

abstract contract BaseIntTest_SetPLP is BaseIntTest_SetPLPTokens {
  constructor() {
    _setupAcceptedToken();
    liquidityHandler.setOrderExecutor(ORDER_EXECUTOR, true);
    configStorage.setServiceExecutor(address(liquidityService), address(liquidityHandler), true);

    vaultStorage.setServiceExecutors(address(liquidityService), true);
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
