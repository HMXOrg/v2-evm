// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";
import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";

import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeploySGlpStakedAdapter is ConfigJsonRepo {
  bytes32 internal constant sglpAssetId = 0x0000000000000000000000000000000000000000000000000000000000000010;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");

    address sglpAddress = getJsonAddress(".tokens.sglp");
    address glpManager = getJsonAddress(".oracles.glpManager");

    address sglpStakedAdapterAddress = address(
      Deployer.deployStakedGlpOracleAdapter(
        address(proxyAdmin),
        IERC20Upgradeable(sglpAddress),
        IGmxGlpManager(glpManager),
        sglpAssetId
      )
    );

    vm.stopBroadcast();

    updateJson(".oracles.sglpStakedAdapter", sglpStakedAdapterAddress);
  }
}
