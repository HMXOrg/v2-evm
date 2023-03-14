// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";

contract DeployHelper is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address configStorageAddress = getJsonAddress(".storages.config");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");

    address tradeHelperAddress = address(
      new TradeHelper(perpStorageAddress, vaultStorageAddress, configStorageAddress)
    );

    vm.stopBroadcast();

    updateJson(".helpers.trade", tradeHelperAddress);
  }
}
