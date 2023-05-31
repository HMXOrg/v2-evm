// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract SetPLP is ConfigJsonRepo {
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

    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](_tokens.length);
    _plpTokenConfig[0] = _getPLPTokenConfigStruct(0.05 ether, 0, 1000e18, true);
    _plpTokenConfig[1] = _getPLPTokenConfigStruct(0, 0, 1000e18, false);
    _plpTokenConfig[2] = _getPLPTokenConfigStruct(0, 0, 1000e18, false);
    _plpTokenConfig[3] = _getPLPTokenConfigStruct(0, 0, 1000e18, false);
    _plpTokenConfig[4] = _getPLPTokenConfigStruct(0, 0, 1000e18, false);
    _plpTokenConfig[5] = _getPLPTokenConfigStruct(0.95 ether, 0, 1000e18, true);

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
