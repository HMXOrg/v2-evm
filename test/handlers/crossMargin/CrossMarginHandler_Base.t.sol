// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, IConfigStorage, IPerpStorage, MockErc20 } from "@hmx-test/base/BaseTest.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";

contract CrossMarginHandler_Base is BaseTest {
  using AddressUtils for address;

  ICrossMarginHandler internal crossMarginHandler;
  ICrossMarginService internal crossMarginService;
  uint8 internal SUB_ACCOUNT_NO = 1;

  bytes[] internal priceDataBytes;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();

    OracleMiddleware(deployed.oracleMiddleware).setAssetPriceConfig(wethAssetId, 1e6, 60);
    OracleMiddleware(deployed.oracleMiddleware).setAssetPriceConfig(wbtcAssetId, 1e6, 60);

    calculator = deployCalculator(
      address(deployed.oracleMiddleware),
      address(vaultStorage),
      address(mockPerpStorage),
      address(configStorage)
    );

    crossMarginService = deployCrossMarginService(address(configStorage), address(vaultStorage), address(calculator));
    crossMarginHandler = deployCrossMarginHandler(address(crossMarginService), address(deployed.pythAdapter.pyth()));

    // Set whitelist for service executor
    configStorage.setServiceExecutor(address(crossMarginService), address(crossMarginHandler), true);

    // Set accepted token deposit/withdraw as WETH and USDC
    IConfigStorage.CollateralTokenConfig memory _collateralConfigWETH = IConfigStorage.CollateralTokenConfig({
      collateralFactorBPS: 0.8 * 1e4,
      accepted: true,
      settleStrategy: address(0)
    });

    IConfigStorage.CollateralTokenConfig memory _collateralConfigUSDC = IConfigStorage.CollateralTokenConfig({
      collateralFactorBPS: 0.8 * 1e4,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(wethAssetId, _collateralConfigWETH);
    configStorage.setCollateralTokenConfig(usdcAssetId, _collateralConfigUSDC);

    // Set market config
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: wethAssetId,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        minLeverageBPS: 1 * 1e4,
        initialMarginFractionBPS: 0.1 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: false,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
        fundingRate: IConfigStorage.FundingRate({ maxFundingRateBPS: 0.0004 * 1e4, maxSkewScaleUSD: 3_000_000 * 1e30 })
      })
    );

    // Mock gas for handler used for update Pyth's prices
    vm.deal(address(crossMarginHandler), 1 ether);

    // Set Oracle data for Price feeding
    {
      deployed.pythAdapter.setPythPriceId(wbtcAssetId, wbtcPriceId);
      deployed.pythAdapter.setPythPriceId(wethAssetId, wethPriceId);

      priceDataBytes = new bytes[](2);
      priceDataBytes[0] = mockPyth.createPriceFeedUpdateData(
        wbtcPriceId,
        20_000 * 1e8,
        500 * 1e8,
        -8,
        20_000 * 1e8,
        500 * 1e8,
        uint64(block.timestamp)
      );
      priceDataBytes[1] = mockPyth.createPriceFeedUpdateData(
        wethPriceId,
        1_500 * 1e8,
        50 * 1e8,
        -8,
        1_500 * 1e8,
        50 * 1e8,
        uint64(block.timestamp)
      );
    }

    // Set market status
    deployed.oracleMiddleware.setUpdater(address(this), true);
    deployed.oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(2)); // active
    deployed.oracleMiddleware.setMarketStatus(wethAssetId, uint8(2)); // active
  }

  /**
   * COMMON FUNCTION
   */

  function getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function simulateAliceDepositToken(address _token, uint256 _depositAmount) internal {
    vm.startPrank(ALICE);
    MockErc20(_token).approve(address(crossMarginHandler), _depositAmount);
    crossMarginHandler.depositCollateral(ALICE, SUB_ACCOUNT_NO, _token, _depositAmount);
    vm.stopPrank();
  }

  function simulateAliceWithdrawToken(address _token, uint256 _withdrawAmount) internal {
    vm.startPrank(ALICE);
    crossMarginHandler.withdrawCollateral(ALICE, SUB_ACCOUNT_NO, _token, _withdrawAmount, priceDataBytes);
    vm.stopPrank();
  }
}
