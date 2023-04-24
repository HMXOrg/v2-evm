// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "lib/pyth-sdk-solidity/IPyth.sol";

import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";
import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeploySGlpStakedAdapter is ConfigJsonRepo {
  bytes32 internal constant sglpAssetId = 0x0000000000000000000000000000000000000000000000000000000000000010;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address sglpAddress = getJsonAddress(".tokens.sglp");
    address glpManager = getJsonAddress(".oracles.glpManager");

    address sglpStakedAdapter = address(
      new StakedGlpOracleAdapter(IERC20(sglpAddress), IGmxGlpManager(glpManager), sglpAssetId)
    );

    vm.stopBroadcast();

    updateJson(".oracles.sglpStakedAdapter", sglpStakedAdapter);
  }
}
