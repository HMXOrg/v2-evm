// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, CrossMarginService, CrossMarginHandler, IConfigStorage, MockErc20 } from "../../base/BaseTest.sol";

contract CrossMarginHandler_Base is BaseTest {
  CrossMarginHandler internal crossMarginHandler;
  CrossMarginService internal crossMarginService;

  uint256 internal SUB_ACCOUNT_NO = 1;

  function setUp() public virtual {
    crossMarginService = deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(mockCalculator)
    );

    crossMarginHandler = deployCrossMarginHandler(
      address(crossMarginService),
      address(configStorage)
    );

    // Set whitelist for service executor
    configStorage.setServiceExecutor(
      address(crossMarginService),
      address(crossMarginHandler),
      true
    );

    // Set accepted token deposit/withdraw as WETH and USDC
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

  /**
   * COMMON FUNCTION
   */

  function getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function simulateAliceDepositToken(
    address _token,
    uint256 _depositAmount
  ) internal {
    vm.startPrank(ALICE);
    MockErc20(_token).approve(address(crossMarginService), _depositAmount);
    crossMarginHandler.depositCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      _token,
      _depositAmount
    );
    vm.stopPrank();
  }

  function simulateAliceWithdrawToken(
    address _token,
    uint256 _withdrawAmount
  ) internal {
    vm.startPrank(ALICE);
    crossMarginHandler.withdrawCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      _token,
      _withdrawAmount
    );
    vm.stopPrank();
  }
}
