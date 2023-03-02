// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseTest, CrossMarginService, IConfigStorage, MockErc20 } from "../../base/BaseTest.sol";
import { console } from "forge-std/console.sol";

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
    configStorage.setServiceExecutor(address(crossMarginService), CROSS_MARGIN_HANDLER, true);

    // @note - ALICE must act as CROSS_MARGIN_HANDLER here because CROSS_MARGIN_HANDLER doesn't included on this unit test yet
    configStorage.setServiceExecutor(address(crossMarginService), ALICE, true);

    // Set accepted token deposit/withdraw
    IConfigStorage.CollateralTokenConfig memory _collateralConfigWETH = IConfigStorage.CollateralTokenConfig({
      decimals: 18,
      collateralFactor: 0.8 ether,
      isStableCoin: false,
      accepted: true,
      settleStrategy: address(0),
      priceConfidentThreshold: 0.01 * 1e18
    });

    IConfigStorage.CollateralTokenConfig memory _collateralConfigUSDC = IConfigStorage.CollateralTokenConfig({
      decimals: 6,
      collateralFactor: 0.8 ether,
      isStableCoin: true,
      accepted: true,
      settleStrategy: address(0),
      priceConfidentThreshold: 0.01 * 1e18
    });

    configStorage.setCollateralTokenConfig(address(weth), _collateralConfigWETH);
    configStorage.setCollateralTokenConfig(address(usdc), _collateralConfigUSDC);
  }

  // =========================================
  // | ------- common function ------------- |
  // =========================================

  function simulateAliceDepositToken(address _token, uint256 _depositAmount) internal {
    vm.startPrank(ALICE);
    // simulate transfer from Handler to VaultStorage
    IERC20(_token).transfer(address(vaultStorage), _depositAmount);
    MockErc20(_token).approve(address(crossMarginService), _depositAmount);
    crossMarginService.depositCollateral(ALICE, 1, _token, _depositAmount);
    vm.stopPrank();
  }

  function simulateAliceWithdrawToken(address _token, uint256 _withdrawAmount) internal {
    vm.startPrank(ALICE);
    crossMarginService.withdrawCollateral(ALICE, 1, _token, _withdrawAmount);
    vm.stopPrank();
  }

  function getSubAccount(address _primary, uint256 _subAccountId) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }
}
