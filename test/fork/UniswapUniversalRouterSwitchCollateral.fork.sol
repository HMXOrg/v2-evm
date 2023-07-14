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
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { IExt01Handler } from "@hmx/handlers/interfaces/IExt01Handler.sol";
import { UniswapUniversalRouterSwitchCollateralExt } from "@hmx/extensions/switch-collateral/UniswapUniversalRouterSwitchCollateralExt.sol";

contract UniswapUniversalRouterSwitchCollateral_ForkTest is TestBase, StdAssertions, StdCheatsSafe {
    uint256 constant V3_SWAP_EXACT_IN = 0x00;

  address internal constant EXT01_EXECUTOR = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;
  address internal constant USER = 0x13b4FFd03e9093465C9dfed09227b6232a823a9b;

  IExt01Handler internal ext01Handler;
  UniswapUniversalRouterSwitchCollateralExt internal uniswapUniversalRouterSwitchCollateralExt;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 110813326);

    vm.startPrank(ForkEnv.multiSig);
    Deployer.upgrade("ConfigStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.configStorage));
    Deployer.upgrade("CrossMarginService", address(ForkEnv.proxyAdmin), address(ForkEnv.crossMarginService));
    vm.stopPrank();

    vm.startPrank(ForkEnv.deployer);
    uniswapUniversalRouterSwitchCollateralExt = UniswapUniversalRouterSwitchCollateralExt(
      address(
        Deployer.deployUniswapUniversalRouterSwitchCollateralExt(
          address(ForkEnv.uniswapPermit2),
          ForkEnv.uniswapUniversalRouter
        )
      )
    );
    ext01Handler = Deployer.deployExt01Handler(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.crossMarginService),
      address(ForkEnv.liquidationService),
      address(ForkEnv.liquidityService),
      address(ForkEnv.tradeService),
      address(ForkEnv.ecoPyth2),
      50
    );
    ext01Handler.setOrderExecutor(EXT01_EXECUTOR, true);
    ext01Handler.setMinExecutionFee(1, 0.1 * 1e9);
    ForkEnv.ecoPyth2.setUpdater(address(ext01Handler), true);
    address[] memory _handlers = new address[](1);
    _handlers[0] = address(ext01Handler);
    address[] memory _services = new address[](1);
    _services[0] = address(ForkEnv.crossMarginService);
    bool[] memory _isAllows = new bool[](1);
    _isAllows[0] = true;
    ForkEnv.configStorage.setServiceExecutors(_handlers, _services, _isAllows);
    ForkEnv.configStorage.setSwitchCollateralExtension(
      address(ForkEnv.usdc_e),
      address(uniswapUniversalRouterSwitchCollateralExt),
      true
    );
    vm.stopPrank();
  }

  function testRevert_WhenNotSwapToToToken() external {
    vm.startPrank(USER);
    bytes memory _uniswapUniversalRouterCmds = abi.encodePacked(bytes1(uint8(V3_SWAP_EXACT_IN)));
    bytes[] memory _uniswapUniversalRouterInput = new btys[](1);
    _uniswapUniversalRouterInput[0] = abi.encode(
      USER,
      1e6,
      0,
      abi.encodePacked(),
      true
    );
    bytes memory _extData = abi.encodeWithSelector(0x24856bc3, )
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams(
        1,
        0,
        abi.encode(0, address(ForkEnv.usdc_e), address(ForkEnv.weth), 1e6, 0, "")
      )
    );
    vm.stopPrank();
  }
}
