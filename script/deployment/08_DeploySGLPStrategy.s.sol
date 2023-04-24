// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { StakedGlpStrategy } from "@hmx/strategies/StakedGlpStrategy.sol";

// interfaces
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

contract DeploySglpStrategy is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address sglp = getJsonAddress(".tokens.sglp");
    address rewardRouter = getJsonAddress(".yieldSources.gmx.rewardRouterV2");
    address rewardTracker = getJsonAddress(".yieldSources.gmx.rewardTracker");
    address glpManager = getJsonAddress(".yieldSources.gmx.glpManager");
    address oracleMiddleware = getJsonAddress(".oracles.middleware");
    address vaultStorage = getJsonAddress(".storages.vault");

    address keeper = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a; // who can execute strategy
    address treasury = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a; // who can receive treasury reward
    uint16 strategyBPS = 1000; //10%
    address strategiesAddress = address(
      new StakedGlpStrategy(
        IERC20(sglp),
        IGmxRewardRouterV2(rewardRouter),
        IGmxRewardTracker(rewardTracker),
        IGmxGlpManager(glpManager),
        IOracleMiddleware(oracleMiddleware),
        IVaultStorage(vaultStorage),
        keeper,
        treasury,
        strategyBPS
      )
    );

    vm.stopBroadcast();

    updateJson(".strategies.stakedGLPStrategy", strategiesAddress);
  }
}
