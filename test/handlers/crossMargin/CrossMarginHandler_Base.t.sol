// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, IConfigStorage, IPerpStorage, MockErc20 } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";

contract CrossMarginHandler_Base is BaseTest {
  ICrossMarginHandler internal crossMarginHandler;
  ICrossMarginService internal crossMarginService;

  uint8 internal SUB_ACCOUNT_NO = 1;
  uint256 internal constant executionOrderFee = 0.0001 ether;

  bytes[] internal priceDataBytes;

  function setUp() public virtual {
    // Set Oracle data for Price feeding
    {
      pythAdapter.setConfig(wbtcAssetId, wbtcPriceId, false);
      pythAdapter.setConfig(wethAssetId, wethPriceId, false);

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
      mockPyth.updatePriceFeeds{ value: mockPyth.getUpdateFee(priceDataBytes) }(priceDataBytes);
    }

    oracleMiddleware.setAssetPriceConfig(wethAssetId, 1e6, 60, address(pythAdapter));
    oracleMiddleware.setAssetPriceConfig(wbtcAssetId, 1e6, 60, address(pythAdapter));

    calculator = Deployer.deployCalculator(
      address(oracleMiddleware),
      address(vaultStorage),
      address(mockPerpStorage),
      address(configStorage)
    );

    crossMarginService = Deployer.deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(perpStorage),
      address(calculator)
    );
    crossMarginHandler = Deployer.deployCrossMarginHandler(
      address(crossMarginService),
      address(pythAdapter.pyth()),
      executionOrderFee
    );

    // Set whitelist for service executor
    configStorage.setServiceExecutor(address(crossMarginService), address(crossMarginHandler), true);
    vaultStorage.setServiceExecutors(address(crossMarginService), true);

    crossMarginHandler.setOrderExecutor(address(this), true);

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
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        minLeverageBPS: 1 * 1e4,
        initialMarginFractionBPS: 0.1 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: false,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0.0004 * 1e4, maxSkewScaleUSD: 3_000_000 * 1e30 })
      })
    );

    // Mock gas for handler used for update Pyth's prices
    vm.deal(address(crossMarginHandler), 1 ether);

    // Set market status
    oracleMiddleware.setUpdater(address(this), true);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(2)); // active
    oracleMiddleware.setMarketStatus(wethAssetId, uint8(2)); // active
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
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, _token, _depositAmount, false);
    vm.stopPrank();
  }

  function simulateAliceWithdrawToken(
    address _token,
    uint256 _withdrawAmount,
    bytes[] memory _priceData,
    bool _shouldUnwrap
  ) internal {
    vm.deal(ALICE, executionOrderFee);

    vm.prank(ALICE);
    uint256 orderIndex = crossMarginHandler.createWithdrawCollateralOrder{ value: executionOrderFee }(
      SUB_ACCOUNT_NO,
      _token,
      _withdrawAmount,
      executionOrderFee,
      _shouldUnwrap
    );

    crossMarginHandler.executeOrder({ _endIndex: orderIndex, _feeReceiver: payable(FEEVER), _priceData: _priceData });
  }
}
