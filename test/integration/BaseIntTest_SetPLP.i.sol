// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetTokens } from "@hmx-test/integration/BaseIntTest_SetTokens.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetPLP is BaseIntTest_SetTokens {
  constructor() {
    // Set PLP token
    configStorage.setPLP(address(plpV2));

    // Set PLP token config for each token
    _addPlpTokenConfig();
  }

  function _addPlpTokenConfig() private {
    address[] memory _tokens = new address[](5);
    _tokens[0] = address(weth);
    _tokens[1] = address(wbtc);
    _tokens[2] = address(dai);
    _tokens[3] = address(usdc);
    _tokens[4] = address(usdt);

    // add Accepted Token for LP config
    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](5);

    // WETH
    _plpTokenConfig[0] = IConfigStorage.PLPTokenConfig({
      targetWeight: 2e17, // 20%
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // WBTC
    _plpTokenConfig[1] = IConfigStorage.PLPTokenConfig({
      targetWeight: 2e17, // 20%
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // DAI
    _plpTokenConfig[2] = IConfigStorage.PLPTokenConfig({
      targetWeight: 1e17, // 10%
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // USDC
    _plpTokenConfig[3] = IConfigStorage.PLPTokenConfig({
      targetWeight: 3e17, // 30%
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // USDT
    _plpTokenConfig[4] = IConfigStorage.PLPTokenConfig({
      targetWeight: 2e17, // 20%
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });

    configStorage.addOrUpdateAcceptedToken(_tokens, _plpTokenConfig);
  }
}
