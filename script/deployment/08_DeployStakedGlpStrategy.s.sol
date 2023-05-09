// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

// interfaces
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";

import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { IStakedGlpStrategy } from "@hmx/strategies/interfaces/IStakedGlpStrategy.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract DeployStakedGlpStrategy is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    address sglp = getJsonAddress(".tokens.sglp");

    IStakedGlpStrategy.StakedGlpStrategyConfig memory stakedGlpStrategyConfig = IStakedGlpStrategy
      .StakedGlpStrategyConfig(
        IGmxRewardRouterV2(getJsonAddress(".yieldSources.gmx.rewardRouterV2")),
        IGmxRewardTracker(getJsonAddress(".yieldSources.gmx.rewardTracker")),
        IGmxGlpManager(getJsonAddress(".yieldSources.gmx.glpManager")),
        IOracleMiddleware(getJsonAddress(".oracles.middleware")),
        IVaultStorage(getJsonAddress(".storages.vault"))
      );

    address keeper = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a; // who can execute strategy
    address treasury = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a; // who can receive treasury reward
    uint16 strategyBPS = 1000; //10%

    address strategiesAddress = address(
      Deployer.deployStakedGlpStrategy(
        address(proxyAdmin),
        IERC20Upgradeable(sglp),
        stakedGlpStrategyConfig,
        treasury,
        strategyBPS
      )
    );

    vm.stopBroadcast();

    updateJson(".strategies.stakedGlpStrategy", strategiesAddress);
  }
}
