// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { console } from "forge-std/console.sol";

contract GetEquity is ConfigJsonRepo {
  function run() public {
    ICalculator calculator = ICalculator(getJsonAddress(".calculator"));
    int256 equity = calculator.getEquity(
      0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a,
      0,
      0x0000000000000000000000000000000000000000000000000000000000000001
    );
    console.logInt(equity);
  }
}
