// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfig } from "../IConfig.sol";

contract Config is IConfig {
  address public constant glpAddress = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
  address public constant glpManagerAddress = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
  address public constant sGlpAddress = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;
  address public constant gmxRewardRouterV2Address = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
  address public constant glpFeeTrackerAddress = 0x4e971a87900b931fF39d1Aad67697F49835400b6;
  address public constant pythAddress = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
  address public constant wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
}
