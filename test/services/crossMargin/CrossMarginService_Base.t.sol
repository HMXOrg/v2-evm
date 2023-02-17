// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, CrossMarginService, IConfigStorage, MockErc20 } from "../../base/BaseTest.sol";

contract CrossMarginService_Base is BaseTest {
  address internal CROSS_MARGIN_HANDLER;

  CrossMarginService crossMarginService;

  function setUp() public virtual {
    CROSS_MARGIN_HANDLER = makeAddr("CROSS_MARGIN_HANDLER");

    crossMarginService = deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(mockCalculator)
    );

    // Set whitelist for service executor
    configStorage.setServiceExecutor(
      address(crossMarginService),
      CROSS_MARGIN_HANDLER,
      true
    );

    // @note - ALICE must act as CROSS_MARGIN_HANDLER here because CROSS_MARGIN_HANDLER doesn't included on this unit test yet
    configStorage.setServiceExecutor(address(crossMarginService), ALICE, true);

    // Set accepted token deposit/withdraw
    IConfigStorage.CollateralTokenConfig
      memory _collateralConfigWETH = IConfigStorage.CollateralTokenConfig({
        decimals: 18,
        collateralFactor: 0.8 ether,
        isStableCoin: false,
        accepted: true,
        settleStrategy: address(0)
      });

    IConfigStorage.CollateralTokenConfig
      memory _collateralConfigUSDC = IConfigStorage.CollateralTokenConfig({
        decimals: 6,
        collateralFactor: 0.8 ether,
        isStableCoin: true,
        accepted: true,
        settleStrategy: address(0)
      });

    configStorage.setCollateralTokenConfig(
      address(weth),
      _collateralConfigWETH
    );
    configStorage.setCollateralTokenConfig(
      address(usdc),
      _collateralConfigUSDC
    );
  }

  // =========================================
  // | ------- common function ------------- |
  // =========================================

  function simulateAliceDepositToken(
    address _token,
    uint256 _depositAmount
  ) internal {
    vm.startPrank(ALICE);
    MockErc20(_token).approve(address(crossMarginService), _depositAmount);
    crossMarginService.depositCollateral(ALICE, _token, _depositAmount);
    vm.stopPrank();
  }

  function simulateAliceWithdrawToken(
    address _token,
    uint256 _withdrawAmount
  ) internal {
    vm.startPrank(ALICE);
    crossMarginService.withdrawCollateral(ALICE, _token, _withdrawAmount);
    vm.stopPrank();
  }
}
