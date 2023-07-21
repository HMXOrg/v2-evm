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
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IExt01Handler } from "@hmx/handlers/interfaces/IExt01Handler.sol";
import { GlpSwitchCollateralExt } from "@hmx/extensions/switch-collateral/GlpSwitchCollateralExt.sol";
import { UniswapUniversalRouterSwitchCollateralExt } from "@hmx/extensions/switch-collateral/UniswapUniversalRouterSwitchCollateralExt.sol";
import { CurveSwitchCollateralExt } from "@hmx/extensions/switch-collateral/CurveSwitchCollateralExt.sol";

contract GlpSwitchCollateralExt_ForkTest is TestBase, Cheats, StdAssertions, StdCheatsSafe {
  uint256 constant V3_SWAP_EXACT_IN = 0x00;

  address internal constant EXT01_EXECUTOR = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;
  address internal constant USER = 0x10C69D9d8AE54FD1Ab12A4beC82c2695b977bcEC;
  uint8 internal constant SUB_ACCOUNT_ID = 0;

  IExt01Handler internal ext01Handler;
  GlpSwitchCollateralExt internal glpSwitchCollateralExt;
  UniswapUniversalRouterSwitchCollateralExt internal uniswapUniversalRouterSwitchCollateralExt;
  CurveSwitchCollateralExt internal curveSwitchCollateralExt;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 113073035);

    vm.startPrank(ForkEnv.multiSig);
    Deployer.upgrade("ConfigStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.configStorage));
    Deployer.upgrade("CrossMarginService", address(ForkEnv.proxyAdmin), address(ForkEnv.crossMarginService));
    vm.stopPrank();

    vm.startPrank(ForkEnv.deployer);
    // Add ARB as collateral
    ForkEnv.configStorage.setAssetConfig(
      "ARB",
      IConfigStorage.AssetConfig({
        assetId: "ARB",
        tokenAddress: address(ForkEnv.arb),
        decimals: 18,
        isStableCoin: false
      })
    );
    ForkEnv.configStorage.setCollateralTokenConfig(
      "ARB",
      IConfigStorage.CollateralTokenConfig({
        collateralFactorBPS: 0.6 * 100_00,
        accepted: true,
        settleStrategy: address(0)
      })
    );
    // Add wstETH as collateral
    ForkEnv.ecoPyth2.insertAssetId("wstETH");
    ForkEnv.pythAdapter.setConfig("wstETH", "wstETH", false);
    ForkEnv.oracleMiddleware.setAssetPriceConfig("wstETH", 0, 60 * 5, address(ForkEnv.pythAdapter));
    ForkEnv.configStorage.setAssetConfig(
      "wstETH",
      IConfigStorage.AssetConfig({
        assetId: "wstETH",
        tokenAddress: address(ForkEnv.wstEth),
        decimals: 18,
        isStableCoin: false
      })
    );
    ForkEnv.configStorage.setCollateralTokenConfig(
      "wstETH",
      IConfigStorage.CollateralTokenConfig({
        collateralFactorBPS: 0.8 * 100_00,
        accepted: true,
        settleStrategy: address(0)
      })
    );
    // Deploy UniswapUniversalRouterSwitchCollateralExt
    uniswapUniversalRouterSwitchCollateralExt = UniswapUniversalRouterSwitchCollateralExt(
      address(
        Deployer.deployUniswapUniversalRouterSwitchCollateralExt(
          address(ForkEnv.uniswapPermit2),
          address(ForkEnv.uniswapUniversalRouter)
        )
      )
    );
    uniswapUniversalRouterSwitchCollateralExt.setPathOf(
      address(ForkEnv.arb),
      address(ForkEnv.weth),
      abi.encodePacked(ForkEnv.arb, uint24(500), ForkEnv.weth)
    );
    uniswapUniversalRouterSwitchCollateralExt.setPathOf(
      address(ForkEnv.weth),
      address(ForkEnv.arb),
      abi.encodePacked(ForkEnv.weth, uint24(500), ForkEnv.arb)
    );
    // Deploy CurveSwitchCollateralExt
    curveSwitchCollateralExt = CurveSwitchCollateralExt(
      payable(address(Deployer.deployCurveSwitchCollateralExt(address(ForkEnv.weth))))
    );
    curveSwitchCollateralExt.setPoolConfigOf(
      address(ForkEnv.weth),
      address(ForkEnv.wstEth),
      address(ForkEnv.curveWstEthPool),
      0,
      1
    );
    curveSwitchCollateralExt.setPoolConfigOf(
      address(ForkEnv.wstEth),
      address(ForkEnv.weth),
      address(ForkEnv.curveWstEthPool),
      1,
      0
    );
    // Deploy GlpSwitchCollateralExt
    glpSwitchCollateralExt = GlpSwitchCollateralExt(
      address(
        Deployer.deployGlpSwitchCollateralExt(
          address(ForkEnv.configStorage),
          address(ForkEnv.weth),
          address(ForkEnv.sGlp),
          address(ForkEnv.glpManager),
          address(ForkEnv.gmxVault),
          address(ForkEnv.gmxRewardRouterV2)
        )
      )
    );
    // Deploy Ext01Handler
    ext01Handler = Deployer.deployExt01Handler(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.crossMarginService),
      address(ForkEnv.liquidationService),
      address(ForkEnv.liquidityService),
      address(ForkEnv.tradeService),
      address(ForkEnv.ecoPyth2),
      50
    );
    // Settings
    ext01Handler.setOrderExecutor(EXT01_EXECUTOR, true);
    ext01Handler.setMinExecutionFee(1, 0.1 * 1e9);
    ForkEnv.ecoPyth2.setUpdater(address(ext01Handler), true);
    address[] memory _handlers = new address[](1);
    _handlers[0] = address(ext01Handler);
    address[] memory _services = new address[](1);
    _services[0] = address(ForkEnv.crossMarginService);
    bool[] memory _isAllows = new bool[](1);
    _isAllows[0] = true;
    ForkEnv.configStorage.setServiceExecutors(_services, _handlers, _isAllows);
    ForkEnv.configStorage.setSwitchCollateralExtension(address(ForkEnv.sGlp), address(glpSwitchCollateralExt), true);
    ForkEnv.configStorage.setSwitchCollateralExtension(address(ForkEnv.weth), address(glpSwitchCollateralExt), true);
    ForkEnv.configStorage.setSwitchCollateralExtension(address(ForkEnv.arb), address(glpSwitchCollateralExt), true);
    ForkEnv.configStorage.setSwitchCollateralExtension(address(ForkEnv.wstEth), address(glpSwitchCollateralExt), true);
    ForkEnv.configStorage.setSwitchCollateralExtension(
      address(ForkEnv.weth),
      address(uniswapUniversalRouterSwitchCollateralExt),
      true
    );
    ForkEnv.configStorage.setSwitchCollateralExtension(
      address(ForkEnv.arb),
      address(uniswapUniversalRouterSwitchCollateralExt),
      true
    );
    ForkEnv.configStorage.setSwitchCollateralExtension(address(ForkEnv.weth), address(curveSwitchCollateralExt), true);
    ForkEnv.configStorage.setSwitchCollateralExtension(
      address(ForkEnv.wstEth),
      address(curveSwitchCollateralExt),
      true
    );
    vm.stopPrank();

    vm.label(address(ext01Handler), "ext01Handler");
    vm.label(address(ForkEnv.crossMarginService), "crossMarginService");
  }

  function testRevert_WhenFromTokenNotCollateral() external {
    vm.startPrank(USER);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          0,
          address(ForkEnv.pendle),
          address(ForkEnv.weth),
          79115385,
          41433673370671066,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();
  }

  function testRevert_WhenToTokenNotCollateral() external {
    vm.startPrank(USER);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          0,
          address(ForkEnv.usdc_e),
          address(ForkEnv.pendle),
          79115385,
          41433673370671066,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();
  }

  function testRevert_WhenFromAndToTokenAreSame() external {
    vm.startPrank(USER);
    vm.expectRevert(abi.encodeWithSignature("IExt01Handler_SameFromToToken()"));
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          0,
          address(ForkEnv.usdc_e),
          address(ForkEnv.usdc_e),
          79115385,
          41433673370671066,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();
  }

  function testRevert_WhenSlippage() external {
    vm.startPrank(USER);
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.sGlp),
          address(ForkEnv.weth),
          5000000000000000000,
          2652487522183761,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    // but change ETH to tick 0 which equals to 1 USD.
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();

    // Trader balance should be the same
    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp)), 5000000000000000000);
  }

  function testRevert_WhenSwitchCollateralMakesEquityBelowIMR() external {
    vm.startPrank(USER);
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.sGlp),
          address(ForkEnv.weth),
          5000000000000000000,
          0,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    // but change ETH to tick 0 which equals to 1 USD.
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0007130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();

    // Trader balance should be the same
    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp)), 5000000000000000000);
  }

  function testCorrectness_WhenSwitchCollateralFromSglpToTokenInGlpVault() external {
    vm.startPrank(USER);
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.sGlp),
          address(ForkEnv.weth),
          5000000000000000000,
          0,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    uint256 _wethBefore = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.weth));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();
    uint256 _wethAfter = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.weth));

    // Trader balance should be the same
    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp)), 0);
    assertEq(_wethAfter - _wethBefore, 2652487522183760);
  }

  function testCorrectness_WhenSwitchCollateralFromTokenInGlpVaultToSglp() external {
    vm.startPrank(USER);
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.weth),
          address(ForkEnv.sGlp),
          ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.weth)),
          0,
          abi.encode(address(glpSwitchCollateralExt), new bytes(0))
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    uint256 _sGlpBefore = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();
    uint256 _sGlpAfter = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp));

    // Trader balance should be the same
    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.weth)), 0);
    assertEq(_sGlpAfter - _sGlpBefore, 74640579149339718);
  }

  function testCorrectness_WhenSwitchCollateralFromSglpToBareErc20() external {
    vm.startPrank(USER);
    // Create switch collateral order from sGLP -> ARB
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.sGlp),
          address(ForkEnv.arb),
          ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp)),
          0,
          abi.encode(
            address(glpSwitchCollateralExt),
            abi.encode(address(uniswapUniversalRouterSwitchCollateralExt), new bytes(0))
          )
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    uint256 _arbBefore = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.arb));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();
    uint256 _arbAfter = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.arb));

    // Trader balance should be the same
    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp)), 0);
    assertEq(_arbAfter - _arbBefore, 3970232321595248857);
  }

  function testCorrectness_WhenSwitchCollateralFromBareErc20ToSglp() external {
    // Motherload ARB for USER
    motherload(address(ForkEnv.arb), USER, 1000 * 1e18);

    vm.startPrank(USER);
    // Deposit ARB to the cross margin account
    ForkEnv.arb.approve(address(ForkEnv.crossMarginHandler), 1000 * 1e18);
    ForkEnv.crossMarginHandler.depositCollateral(SUB_ACCOUNT_ID, address(ForkEnv.arb), 1000 * 1e18, false);
    // Create switch collateral order from sGLP -> ARB
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.arb),
          address(ForkEnv.sGlp),
          ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.arb)),
          0,
          abi.encode(
            address(glpSwitchCollateralExt),
            abi.encode(address(uniswapUniversalRouterSwitchCollateralExt), new bytes(0))
          )
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    uint256 _sGlpBefore = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();
    uint256 _sGlpAfter = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp));

    // Trader balance should be the same
    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.arb)), 0);
    assertEq(_sGlpAfter - _sGlpBefore, 1251816487838549309485);
  }

  function testCorrectness_WhenSwitchCollateralFromSglpToWstEth() external {
    vm.startPrank(USER);
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        data: abi.encode(
          SUB_ACCOUNT_ID,
          address(ForkEnv.sGlp),
          address(ForkEnv.wstEth),
          5000000000000000000,
          0,
          abi.encode(address(glpSwitchCollateralExt), abi.encode(address(curveSwitchCollateralExt), new bytes(0)))
        )
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    // Add 012bb4 => 76724 tick for wstETH price
    uint256 _wstEthBefore = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.wstEth));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f72012bb40000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    ext01Handler.executeOrders(1, payable(EXT01_EXECUTOR), _priceData, _publishTimeData, block.timestamp, "");
    vm.stopPrank();
    uint256 _wstEthAfter = ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.wstEth));

    assertEq(ForkEnv.vaultStorage.traderBalances(USER, address(ForkEnv.sGlp)), 0);
    assertEq(_wstEthAfter - _wstEthBefore, 2341647970371989);
  }
}
