// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TestBase} from "forge-std/Base.sol";
import {console2} from "forge-std/console2.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {MockErc20} from "../mocks/MockErc20.sol";
import {MockPyth} from "pyth-sdk-solidity/MockPyth.sol";
import {Deployment} from "../../script/Deployment.s.sol";

abstract contract BaseTest is TestBase, Deployment, StdAssertions {
  address internal constant ALICE = address(234892);
  address internal constant BOB = address(234893);
  address internal constant CAROL = address(234894);
  address internal constant DAVE = address(234895);

  MockPyth internal mockPyth;

  MockErc20 internal weth;
  MockErc20 internal wbtc;
  MockErc20 internal dai;
  MockErc20 internal usdc;

  constructor() {
    mockPyth = new MockPyth(60, 1);

    weth = deployMockErc20("Wrapped Ethereum", "WETH", 18);
    wbtc = deployMockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = deployMockErc20("DAI Stablecoin", "DAI", 18);
    usdc = deployMockErc20("USD Coin", "USDC", 6);
  }

  function deployMockErc20(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) internal returns (MockErc20) {
    return new MockErc20(name, symbol, decimals);
  }

  function deployPerp88v2()
    internal
    returns (Deployment.DeployReturnVars memory)
  {
    return deploy(mockPyth);
  }
}
