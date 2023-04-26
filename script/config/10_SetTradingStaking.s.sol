// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { TradingStaking } from "@hmx/staking/TradingStaking.sol";

contract SetTradingStaking is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    TradingStaking tradingStaking = TradingStaking(getJsonAddress(".staking.trading"));
    uint256[] memory marketIndex = new uint256[](1);

    marketIndex[0] = 0; // ETHUSD Market
    tradingStaking.addRewarder(getJsonAddress(".rewarders.tradingStaking.ETHUSD"), marketIndex);

    marketIndex[0] = 1; // BTCUSD Market
    tradingStaking.addRewarder(getJsonAddress(".rewarders.tradingStaking.BTCUSD"), marketIndex);

    marketIndex[0] = 2; // AAPLUSD Market
    tradingStaking.addRewarder(getJsonAddress(".rewarders.tradingStaking.AAPLUSD"), marketIndex);

    marketIndex[0] = 3; // JPYUSD Market
    tradingStaking.addRewarder(getJsonAddress(".rewarders.tradingStaking.JPYUSD"), marketIndex);

    vm.stopBroadcast();
  }
}
