// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { ICalcPriceAdapter } from "@hmx/oracles/interfaces/ICalcPriceAdapter.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

contract PendlePTAdapter_ForkTest is ForkEnv, Cheats {
  ICalcPriceAdapter pendlePTAdapter;
  address internal marketAddress = 0x5E03C94Fc5Fb2E21882000A96Df0b63d2c4312e2;
  address internal pendlePtLpOracle = 0x1Fd95db7B7C0067De8D45C0cb35D59796adfD187;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 204311833);
    pendlePTAdapter = Deployer.deployPendlePTAdapter(3, marketAddress, pendlePtLpOracle, 1800);
  }

  function testCorrectness_getPriceFromBuildData() external {
    IEcoPythCalldataBuilder3.BuildData[] memory _buildDatas = new IEcoPythCalldataBuilder3.BuildData[](4);
    _buildDatas[0].assetId = "EUR";
    _buildDatas[0].priceE8 = 1.05048e8;

    _buildDatas[1].assetId = "UNKNOWN1";
    _buildDatas[1].priceE8 = 1.1e8;

    _buildDatas[2].assetId = "UNKNOWN2";
    _buildDatas[2].priceE8 = 2.2e8;

    _buildDatas[3].assetId = "ezETH";
    _buildDatas[3].priceE8 = 3174.68 * 1e8;
    uint256 price = pendlePTAdapter.getPrice(_buildDatas);

    // PT exchange rate = 0.936374592931958561 ezETH
    // ezETH price = 3174.68 USD
    // PT ezETH price = 0.936374592931958561 * 3174.68 = 2972.689692689230204435 USD
    assertEq(price, 2972.689692689230204435 * 1e18);
  }

  function testCorrectness_getPriceFromArray() external {
    uint256[] memory priceE8s = new uint256[](1);
    priceE8s[0] = 3174.68 * 1e8;
    uint256 price = pendlePTAdapter.getPrice(priceE8s);

    // PT exchange rate = 0.936374592931958561 ezETH
    // ezETH price = 3174.68 USD
    // PT ezETH price = 0.936374592931958561 * 3174.68 = 2972.689692689230204435 USD
    assertEq(price, 2972.689692689230204435 * 1e18);
  }
}
