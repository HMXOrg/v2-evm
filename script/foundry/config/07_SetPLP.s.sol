// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract SetHLP is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    _setupAcceptedToken();

    vm.stopBroadcast();
  }

  function _setupAcceptedToken() private {
    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));

    address[] memory _tokens = new address[](6);
    _tokens[0] = getJsonAddress(".tokens.usdc");
    _tokens[1] = getJsonAddress(".tokens.usdt");
    _tokens[2] = getJsonAddress(".tokens.dai");
    _tokens[3] = getJsonAddress(".tokens.weth");
    _tokens[4] = getJsonAddress(".tokens.wbtc");
    _tokens[5] = getJsonAddress(".tokens.sglp");

    IConfigStorage.HLPTokenConfig[] memory _hlpTokenConfig = new IConfigStorage.HLPTokenConfig[](_tokens.length);
    _hlpTokenConfig[0] = _getHLPTokenConfigStruct(0.05 ether, 0, 1000e18, true);
    _hlpTokenConfig[1] = _getHLPTokenConfigStruct(0, 0, 1000e18, false);
    _hlpTokenConfig[2] = _getHLPTokenConfigStruct(0, 0, 1000e18, false);
    _hlpTokenConfig[3] = _getHLPTokenConfigStruct(0, 0, 1000e18, false);
    _hlpTokenConfig[4] = _getHLPTokenConfigStruct(0, 0, 1000e18, false);
    _hlpTokenConfig[5] = _getHLPTokenConfigStruct(0.95 ether, 0, 1000e18, true);

    configStorage.addOrUpdateAcceptedToken(_tokens, _hlpTokenConfig);
  }

  function _getHLPTokenConfigStruct(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff,
    bool _accepted
  ) private pure returns (IConfigStorage.HLPTokenConfig memory) {
    return
      IConfigStorage.HLPTokenConfig({
        targetWeight: _targetWeight,
        bufferLiquidity: _bufferLiquidity,
        maxWeightDiff: _maxWeightDiff,
        accepted: _accepted
      });
  }
}
