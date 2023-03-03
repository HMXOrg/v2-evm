// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, IConfigStorage, IPerpStorage, MockErc20 } from "../../base/BaseTest.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";

contract CrossMarginHandler_Base is BaseTest {
  using AddressUtils for address;

  ICrossMarginHandler internal crossMarginHandler;
  ICrossMarginService internal crossMarginService;

  uint256 internal SUB_ACCOUNT_NO = 1;

  bytes[] internal priceDataBytes;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();

    OracleMiddleware(deployed.oracleMiddleware).setAssetPriceConfig("ETH", 1e6, 60);
    OracleMiddleware(deployed.oracleMiddleware).setAssetPriceConfig("BTC", 1e6, 60);
    OracleMiddleware(deployed.oracleMiddleware).setAssetPriceConfig(address(wbtc).toBytes32(), 1e6, 60);
    OracleMiddleware(deployed.oracleMiddleware).setAssetPriceConfig(address(weth).toBytes32(), 1e6, 60);

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
      collateralFactor: 0.8 ether,
      accepted: true,
      settleStrategy: address(0)
    });

    IConfigStorage.CollateralTokenConfig memory _collateralConfigUSDC = IConfigStorage.CollateralTokenConfig({
      collateralFactor: 0.8 ether,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(address(weth).toBytes32(), _collateralConfigWETH);
    configStorage.setCollateralTokenConfig(address(usdc).toBytes32(), _collateralConfigUSDC);

    // Set market config
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: address(weth).toBytes32(),
        assetClass: 1,
        maxProfitRate: 9e18,
        minLeverage: 1,
        initialMarginFraction: 0.1 * 1e18,
        maintenanceMarginFraction: 0.005 * 1e18,
        increasePositionFeeRate: 0,
        decreasePositionFeeRate: 0,
        allowIncreasePosition: false,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 4 * 1e14, maxSkewScaleUSD: 3_000_000 * 1e30 })
      })
    );

    // Mock gas for handler used for update Pyth's prices
    vm.deal(address(crossMarginHandler), 1 ether);

    // Set Oracle data for Price feeding
    {
      deployed.pythAdapter.setPythPriceId(address(wbtc).toBytes32(), wbtcPriceId);
      deployed.pythAdapter.setPythPriceId(address(weth).toBytes32(), wethPriceId);

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
    deployed.oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(2)); // active
    deployed.oracleMiddleware.setMarketStatus(address(weth).toBytes32(), uint8(2)); // active
  }

  /**
   * COMMON FUNCTION
   */

  function getSubAccount(address _primary, uint256 _subAccountId) internal pure returns (address _subAccount) {
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
