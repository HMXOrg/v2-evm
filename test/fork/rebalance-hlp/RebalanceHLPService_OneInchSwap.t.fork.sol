// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// HMX
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";

/// HMX Tests
import { ForkEnvWithActions } from "@hmx-test/fork/bases/ForkEnvWithActions.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { MockEcoPyth } from "@hmx-test/mocks/MockEcoPyth.sol";

contract RebalanceHLPService_OneInchSwapForkTest is ForkEnvWithActions {
  function setUp() external {
    // Fork Network
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 148273154);

    // Mock EcoPyth
    makeEcoPythMockable();

    // Upgrade instances
    vm.startPrank(proxyAdmin.owner());
    Deployer.upgrade("RebalanceHLPHandler", address(proxyAdmin), address(rebalanceHLPHandler));
    Deployer.upgrade("RebalanceHLPService", address(proxyAdmin), address(rebalanceHLPService));
    vm.stopPrank();

    // Set oneInch router
    vm.startPrank(rebalanceHLPService.owner());
    rebalanceHLPService.setOneInchRouter(oneInchRouter);
    vm.stopPrank();
  }

  function testRevert_WhenSlippage() external {
    // It's ugly but yeah
    // It is oneInchData for swapping 5m USDC.e to USDC
    bytes
      memory oneInchData = hex"12aa3caf000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000d63d4542aa563fdb10f4c3785a4b90e89be197c00000000000000000000000000000000000000000000000000000048c2739500000000000000000000000000000000000000000000000000000000368e2b3dfeb000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009930000000000000000000000000000000000000009750009470008fd0008e300a0c9e75c48000000000000000009010000000000000000000000000000000000000000000000000008b500044300a007e5c0d200000000000000000000000000000000000000000000000000041f00030400a0c9e75c4800000000000f0e0a06050000000000000000000000000000000002d60001ba00016b00011c0000ee00a007e5c0d20000000000000000000000000000000000000000000000000000ca0000b051007f90122bf0700f9e7e1f688fe926940e8839f353ff970a61a04b1ca14834a43f5de4533ebddb5cc800443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008b9f2912c0020d6bdbf78fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900a0a87a1ae8e4b2dfc82977dd2dce7e8d37895a6a8f50cbb4fbff970a61a04b1ca14834a43f5de4533ebddb5cc802a00000000000000000000000000000000000000000000000000000001173e96666ee63c1e5008c9d230d45d6cfee39a6680fb7cb7e8de7ea8e71ff970a61a04b1ca14834a43f5de4533ebddb5cc802a0000000000000000000000000000000000000000000000000000000186f6db745ee63c1e5003ab5dd69950a948c55d1fbfb7500bf92b4bd4c48ff970a61a04b1ca14834a43f5de4533ebddb5cc84330c23f1d198477c0bcae0cac2ec734ceda438a89900000000000000000000000000000000000000000000000000000001a2e02f09d002424b31a0c000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fffd8963efd1fc6a506488495d951d5263988d2500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc800a0c9e75c48000000000000002d04010000000000000000000000000000000000000000000000ed00009e00004f02a000000000000000000000000000000000000000000000000000000001beef0421ee63c1e5007e928afb59f5de9d2f4d162f754c6eb40c88aa8efd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb902a000000000000000000000000000000000000000000000000000000006fbc307a5ee63c1e500be3ad6a5669dc0b8b12febc03608860c31e2eef6fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb902a00000000000000000000000000000000000000000000000000000004e903a0106ee63c1e500df63268af25a2a69c07d09a88336cd9424269a1ffd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900a0c9e75c48000024030303020101010000000000000004440003b60003670003180002c900027a00015e0000f05100c6bc781e20f9323012f6e422bdf552ff06ba6cd1ff970a61a04b1ca14834a43f5de4533ebddb5cc800449908fc8b000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000000000000000000000000000000000006551c5e14801de568fd89b3349a766f45d5ab2a7c0510f476a80ff970a61a04b1ca14834a43f5de4533ebddb5cc853c059a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd094310ff128f2308793883acadd5d207ee921b7eedce0e0000000000000000000000000000000000000000000000000000000fb6ae6097002424b31a0c000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fffd8963efd1fc6a506488495d951d5263988d2500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc802a00000000000000000000000000000000000000000000000000000001f6d811072ee63c1e500c86eb7b85807020b4548ee05b54bfc956eebbfcdff970a61a04b1ca14834a43f5de4533ebddb5cc800a0fbb7cd0600423a1323c871abc9d89eb06855bf5347048fc4a5000000000000000000000496ff970a61a04b1ca14834a43f5de4533ebddb5cc8af88d065e77c8cc2239327c5edb3a432268e583102a00000000000000000000000000000000000000000000000000000002f22e3f4a3ee63c1e5008e295789c9465487074a65b1ae9ce0351172393fff970a61a04b1ca14834a43f5de4533ebddb5cc802a00000000000000000000000000000000000000000000000000000002f244b5d57ee63c1e500562d29b54d2c57f8620c920415c4dceadd6de2d2ff970a61a04b1ca14834a43f5de4533ebddb5cc84820489ee077994b6658eafa855c308275ead8097c4aff970a61a04b1ca14834a43f5de4533ebddb5cc893316212000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090020d6bdbf78af88d065e77c8cc2239327c5edb3a432268e583100a0f2fa6b66af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000000000000000000000000000000000048bd8efd53a000000000000000000000000004c4f5a80a06c4eca27af88d065e77c8cc2239327c5edb3a432268e58311111111254eeb25477b68fb85ed929f73a960582000000000000000000000000008b1ccac8";

    // Get lastest price data
    (
      bytes32[] memory priceData,
      bytes32[] memory publishedTimeData,
      uint256 minPublishedTime,
      bytes32 encodedVaas
    ) = MockEcoPyth(address(ecoPyth2)).getLastestPriceUpdateData();

    // Start a session as deployer
    vm.startPrank(deployer);
    // Swap from sGLP to USDC_e so we have >5m USDC_e
    address[] memory path = new address[](2);
    path[0] = address(sglp);
    path[1] = address(usdc_e);
    rebalanceHLPHandler.swap(
      IRebalanceHLPService.SwapParams({ amountIn: 1895556.82845582329317269 * 1e18, minAmountOut: 0, path: path }),
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );
    // Swap 5m USDC_e to USDC
    uint256 usdcLiquidityBefore = vaultStorage.hlpLiquidity(address(usdc));
    uint256 usdc_eLiquidityBefore = vaultStorage.hlpLiquidity(address(usdc_e));

    path[0] = address(usdc_e);
    path[1] = address(usdc);
    vm.expectRevert(abi.encodeWithSignature("RebalanceHLPService_Slippage()"));
    rebalanceHLPHandler.oneInchSwap(
      IRebalanceHLPService.SwapParams({ amountIn: 5_000_000 * 1e6, minAmountOut: 4998690.547064 * 1e6, path: path }),
      oneInchData,
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );

    uint256 usdcLiquidityAfter = vaultStorage.hlpLiquidity(address(usdc));
    uint256 usdc_eLiquidityAfter = vaultStorage.hlpLiquidity(address(usdc_e));

    vm.stopPrank();

    assertEq(usdc.balanceOf(address(rebalanceHLPService)), 0, "should not has any USDC in RebalanceHLPService");
    assertEq(usdcLiquidityAfter - usdcLiquidityBefore, 0, "USDC liquidity should remains the same");
    assertEq(usdc_eLiquidityBefore - usdc_eLiquidityAfter, 0, "USDC.e liquidity should remains the same");
  }

  function testCorrectness_WhenSwapViaOneInch() external {
    // It's ugly but yeah
    // It is oneInchData for swapping 5m USDC.e to USDC
    bytes
      memory oneInchData = hex"12aa3caf000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000d63d4542aa563fdb10f4c3785a4b90e89be197c00000000000000000000000000000000000000000000000000000048c2739500000000000000000000000000000000000000000000000000000000368e2b3dfeb000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009930000000000000000000000000000000000000009750009470008fd0008e300a0c9e75c48000000000000000009010000000000000000000000000000000000000000000000000008b500044300a007e5c0d200000000000000000000000000000000000000000000000000041f00030400a0c9e75c4800000000000f0e0a06050000000000000000000000000000000002d60001ba00016b00011c0000ee00a007e5c0d20000000000000000000000000000000000000000000000000000ca0000b051007f90122bf0700f9e7e1f688fe926940e8839f353ff970a61a04b1ca14834a43f5de4533ebddb5cc800443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008b9f2912c0020d6bdbf78fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900a0a87a1ae8e4b2dfc82977dd2dce7e8d37895a6a8f50cbb4fbff970a61a04b1ca14834a43f5de4533ebddb5cc802a00000000000000000000000000000000000000000000000000000001173e96666ee63c1e5008c9d230d45d6cfee39a6680fb7cb7e8de7ea8e71ff970a61a04b1ca14834a43f5de4533ebddb5cc802a0000000000000000000000000000000000000000000000000000000186f6db745ee63c1e5003ab5dd69950a948c55d1fbfb7500bf92b4bd4c48ff970a61a04b1ca14834a43f5de4533ebddb5cc84330c23f1d198477c0bcae0cac2ec734ceda438a89900000000000000000000000000000000000000000000000000000001a2e02f09d002424b31a0c000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fffd8963efd1fc6a506488495d951d5263988d2500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc800a0c9e75c48000000000000002d04010000000000000000000000000000000000000000000000ed00009e00004f02a000000000000000000000000000000000000000000000000000000001beef0421ee63c1e5007e928afb59f5de9d2f4d162f754c6eb40c88aa8efd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb902a000000000000000000000000000000000000000000000000000000006fbc307a5ee63c1e500be3ad6a5669dc0b8b12febc03608860c31e2eef6fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb902a00000000000000000000000000000000000000000000000000000004e903a0106ee63c1e500df63268af25a2a69c07d09a88336cd9424269a1ffd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900a0c9e75c48000024030303020101010000000000000004440003b60003670003180002c900027a00015e0000f05100c6bc781e20f9323012f6e422bdf552ff06ba6cd1ff970a61a04b1ca14834a43f5de4533ebddb5cc800449908fc8b000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000000000000000000000000000000000006551c5e14801de568fd89b3349a766f45d5ab2a7c0510f476a80ff970a61a04b1ca14834a43f5de4533ebddb5cc853c059a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd094310ff128f2308793883acadd5d207ee921b7eedce0e0000000000000000000000000000000000000000000000000000000fb6ae6097002424b31a0c000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fffd8963efd1fc6a506488495d951d5263988d2500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc802a00000000000000000000000000000000000000000000000000000001f6d811072ee63c1e500c86eb7b85807020b4548ee05b54bfc956eebbfcdff970a61a04b1ca14834a43f5de4533ebddb5cc800a0fbb7cd0600423a1323c871abc9d89eb06855bf5347048fc4a5000000000000000000000496ff970a61a04b1ca14834a43f5de4533ebddb5cc8af88d065e77c8cc2239327c5edb3a432268e583102a00000000000000000000000000000000000000000000000000000002f22e3f4a3ee63c1e5008e295789c9465487074a65b1ae9ce0351172393fff970a61a04b1ca14834a43f5de4533ebddb5cc802a00000000000000000000000000000000000000000000000000000002f244b5d57ee63c1e500562d29b54d2c57f8620c920415c4dceadd6de2d2ff970a61a04b1ca14834a43f5de4533ebddb5cc84820489ee077994b6658eafa855c308275ead8097c4aff970a61a04b1ca14834a43f5de4533ebddb5cc893316212000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090020d6bdbf78af88d065e77c8cc2239327c5edb3a432268e583100a0f2fa6b66af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000000000000000000000000000000000048bd8efd53a000000000000000000000000004c4f5a80a06c4eca27af88d065e77c8cc2239327c5edb3a432268e58311111111254eeb25477b68fb85ed929f73a960582000000000000000000000000008b1ccac8";

    // Get lastest price data
    (
      bytes32[] memory priceData,
      bytes32[] memory publishedTimeData,
      uint256 minPublishedTime,
      bytes32 encodedVaas
    ) = MockEcoPyth(address(ecoPyth2)).getLastestPriceUpdateData();

    // Start a session as deployer
    vm.startPrank(deployer);
    // Swap from sGLP to USDC_e so we have >5m USDC_e
    address[] memory path = new address[](2);
    path[0] = address(sglp);
    path[1] = address(usdc_e);
    rebalanceHLPHandler.swap(
      IRebalanceHLPService.SwapParams({ amountIn: 1895556.82845582329317269 * 1e18, minAmountOut: 0, path: path }),
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );
    // Swap 5m USDC_e to USDC
    uint256 usdcLiquidityBefore = vaultStorage.hlpLiquidity(address(usdc));

    path[0] = address(usdc_e);
    path[1] = address(usdc);
    rebalanceHLPHandler.oneInchSwap(
      IRebalanceHLPService.SwapParams({ amountIn: 5_000_000 * 1e6, minAmountOut: 0, path: path }),
      oneInchData,
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );

    uint256 usdcLiquidityAfter = vaultStorage.hlpLiquidity(address(usdc));

    vm.stopPrank();

    assertEq(usdc.balanceOf(address(rebalanceHLPService)), 0, "should not has any USDC in RebalanceHLPService");
    assertEq(
      usdcLiquidityAfter - usdcLiquidityBefore,
      4998690.547063 * 1e6,
      "USDC liquidity should increase by 4998690.547063"
    );
  }
}