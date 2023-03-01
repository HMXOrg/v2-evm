// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfig } from "../IConfig.sol";

contract Config is IConfig {
  address public constant glpAddress = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
  address public constant glpManagerAddress = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
  address public constant stkGlpAddress = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;
  address public constant gmxRewardRouterV2Address = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
}
