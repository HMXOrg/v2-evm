// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";

contract MockGmxRewardRouterV2 is IGmxRewardRouterV2 {
  function mintAndStakeGlp(
    address /*_token*/,
    uint256 /*_amount*/,
    uint256 /*_minUsdg*/,
    uint256 /*_minGlp*/
  ) external returns (uint256) {
    return 0;
  }

  function mintAndStakeGlpETH(uint256 /*_minUsdg*/, uint256 /*_minGlp*/) external payable returns (uint256) {
    return 0;
  }

  function unstakeAndRedeemGlp(
    address /*_tokenOut*/,
    uint256 /*_glpAmount*/,
    uint256 /*_minOut*/,
    address /*_receiver*/
  ) external returns (uint256) {
    return 0;
  }
}
