// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { UnstakedGlpStrategy } from "@hmx/strategies/UnstakedGlpStrategy.sol";

// interfaces
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract DeployUnstakedGlpStrategy is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    address sglp = getJsonAddress(".tokens.sglp");
    address rewardRouter = getJsonAddress(".yieldSources.gmx.rewardRouterV2");
    address vaultStorage = getJsonAddress(".storages.vault");

    address strategiesAddress = address(
      Deployer.deployUnstakedGlpStrategy(
        address(proxyAdmin),
        IERC20Upgradeable(address(sglp)),
        IGmxRewardRouterV2(rewardRouter),
        IVaultStorage(vaultStorage)
      )
    );

    vm.stopBroadcast();

    updateJson(".strategies.unstakedGlpStrategy", strategiesAddress);
  }
}
