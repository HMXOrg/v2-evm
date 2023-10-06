// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

// to-upgrade contract
import { HLP } from "@hmx/contracts/HLP.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";

import { TradeService } from "@hmx/services/TradeService.sol";
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";

import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";
import { OrderReader } from "@hmx/readers/OrderReader.sol";

// Storage
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { UncheckedEcoPythCalldataBuilder } from "@hmx/oracles/UncheckedEcoPythCalldataBuilder.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { AdaptiveFeeCalculator } from "@hmx/contracts/AdaptiveFeeCalculator.sol";
import { OrderbookOracle } from "@hmx/oracles/OrderbookOracle.sol";

contract Smoke_Base is ForkEnv {
  uint256 internal constant BPS = 10_000;
  uint8 internal constant ASSET_CLASS_CRYPTO = 0;
  uint8 internal constant ASSET_CLASS_FOREX = 2;
  uint8 internal constant ASSET_CLASS_COMMODITIES = 3;

  UncheckedEcoPythCalldataBuilder uncheckedBuilder;
  OrderReader newOrderReader;

  function setUp() public virtual {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 137731921);

    uncheckedBuilder = new UncheckedEcoPythCalldataBuilder(ForkEnv.ecoPyth2, ForkEnv.glpManager, ForkEnv.sglp);

    // -- UPGRADE -- //
    vm.startPrank(ForkEnv.proxyAdmin.owner());
    Deployer.upgrade("Calculator", address(ForkEnv.proxyAdmin), address(ForkEnv.calculator));
    Deployer.upgrade("HLP", address(ForkEnv.proxyAdmin), address(ForkEnv.hlp));
    Deployer.upgrade("BotHandler", address(ForkEnv.proxyAdmin), address(ForkEnv.botHandler));
    Deployer.upgrade("LimitTradeHandler", address(ForkEnv.proxyAdmin), address(ForkEnv.limitTradeHandler));
    Deployer.upgrade("TradeService", address(ForkEnv.proxyAdmin), address(ForkEnv.tradeService));
    Deployer.upgrade("CrossMarginService", address(ForkEnv.proxyAdmin), address(ForkEnv.crossMarginService));
    Deployer.upgrade("TradeHelper", address(ForkEnv.proxyAdmin), address(ForkEnv.tradeHelper));
    Deployer.upgrade("ConfigStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.configStorage));
    Deployer.upgrade("PerpStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.perpStorage));
    Deployer.upgrade("LiquidationService", address(ForkEnv.proxyAdmin), address(ForkEnv.liquidationService));

    newOrderReader = new OrderReader(
      address(ForkEnv.configStorage),
      address(ForkEnv.perpStorage),
      address(ForkEnv.oracleMiddleware),
      address(ForkEnv.limitTradeHandler)
    );
    vm.stopPrank();

    adaptiveFeeCalculator = new AdaptiveFeeCalculator();
    orderbookOracle = new OrderbookOracle();

    _setUpOrderbookOracle();

    vm.startPrank(TradeHelper(address(tradeHelper)).owner());
    tradeHelper.setAdaptiveFeeCalculator(address(adaptiveFeeCalculator));
    tradeHelper.setOrderbookOracle(address(orderbookOracle));
    tradeHelper.setMaxAdaptiveFeeBps(500);
    vm.stopPrank();

    _setMarketConfig();
  }

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  function _setTickPriceZero()
    internal
    view
    returns (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData)
  {
    int24[] memory tickPrices = new int24[](34);
    uint24[] memory publishTimeDiffs = new uint24[](34);
    for (uint i = 0; i < 34; i++) {
      tickPrices[i] = 0;
      publishTimeDiffs[i] = 0;
    }

    priceUpdateData = ForkEnv.ecoPyth2.buildPriceUpdateData(tickPrices);
    publishTimeUpdateData = ForkEnv.ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
  }

  function _setPriceData(
    uint64 _priceE8
  ) internal view returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34
    assetIds = new bytes32[](len - 1);
    prices = new uint64[](len - 1);
    shouldInverts = new bool[](len - 1);

    for (uint i = 1; i < len; i++) {
      assetIds[i - 1] = pythRes[i];
      prices[i - 1] = _priceE8 * 1e8;
      if (i == 4) {
        shouldInverts[i - 1] = true; // JPY
      } else {
        shouldInverts[i - 1] = false;
      }
    }
  }

  function _buildDataForPrice() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _buildDataForPriceWithSpecificPrice(
    bytes32 assetId,
    int64 priceE8
  ) internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory assetIds = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = assetIds.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      data[i - 1].assetId = assetIds[i];
      if (assetId == assetIds[i]) {
        data[i - 1].priceE8 = priceE8;
      } else {
        data[i - 1].priceE8 = ForkEnv.ecoPyth2.getPriceUnsafe(assetIds[i]).price;
      }
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _buildDataForPriceWithSpecificPrice(
    bytes32[] memory assetIdsToManipulate,
    int64[] memory pricesE8ToManipulate
  ) internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory assetIds = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = assetIds.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      data[i - 1].assetId = assetIds[i];
      for (uint j = 0; j < assetIdsToManipulate.length; j++) {
        if (assetIdsToManipulate[j] == assetIds[i]) {
          data[i - 1].priceE8 = pricesE8ToManipulate[j];
        } else {
          data[i - 1].priceE8 = ForkEnv.ecoPyth2.getPriceUnsafe(assetIds[i]).price;
        }
      }
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _validateClosedPosition(bytes32 _id) internal {
    IPerpStorage.Position memory _position = ForkEnv.perpStorage.getPositionById(_id);
    // As the position has been closed, the gotten one should be empty stuct
    assertEq(_position.primaryAccount, address(0));
    assertEq(_position.marketIndex, 0);
    assertEq(_position.avgEntryPriceE30, 0);
    assertEq(_position.entryBorrowingRate, 0);
    assertEq(_position.reserveValueE30, 0);
    assertEq(_position.lastIncreaseTimestamp, 0);
    assertEq(_position.positionSizeE30, 0);
    assertEq(_position.realizedPnl, 0);
    assertEq(_position.lastFundingAccrued, 0);
    assertEq(_position.subAccountId, 0);
  }

  function _checkIsUnderMMR(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256
  ) internal view returns (bool) {
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    IConfigStorage.MarketConfig memory config = ForkEnv.configStorage.getMarketConfigByIndex(_marketIndex);

    int256 _subAccountEquity = ForkEnv.calculator.getEquity(_subAccount, 0, config.assetId);
    uint256 _mmr = ForkEnv.calculator.getMMR(_subAccount);
    if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) return true;
    return false;
  }

  function _setMarketConfig() internal {
    vm.startPrank(ForkEnv.configStorage.owner());
    ForkEnv.configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: "ETH",
        maxLongPositionSize: 5000000 * 1e30,
        maxShortPositionSize: 5000000 * 1e30,
        increasePositionFeeRateBPS: 4, // 0.04%
        decreasePositionFeeRateBPS: 4, // 0.04%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 2000000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      1,
      IConfigStorage.MarketConfig({
        assetId: "BTC",
        maxLongPositionSize: 5000000 * 1e30,
        maxShortPositionSize: 5000000 * 1e30,
        increasePositionFeeRateBPS: 4, // 0.04%
        decreasePositionFeeRateBPS: 4, // 0.04%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 3000000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      3,
      IConfigStorage.MarketConfig({
        assetId: "JPY",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      4,
      IConfigStorage.MarketConfig({
        assetId: "XAU",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 5, // 0.05%
        decreasePositionFeeRateBPS: 5, // 0.05%
        initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
        maintenanceMarginFractionBPS: 100, // MMF = 1%
        maxProfitRateBPS: 75000, // 750%
        assetClass: ASSET_CLASS_COMMODITIES,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      8,
      IConfigStorage.MarketConfig({
        assetId: "EUR",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      9,
      IConfigStorage.MarketConfig({
        assetId: "XAG",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 5, // 0.05%
        decreasePositionFeeRateBPS: 5, // 0.05%
        initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
        maintenanceMarginFractionBPS: 100, // MMF = 1%
        maxProfitRateBPS: 75000, // 750%
        assetClass: ASSET_CLASS_COMMODITIES,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      10,
      IConfigStorage.MarketConfig({
        assetId: "AUD",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      11,
      IConfigStorage.MarketConfig({
        assetId: "GBP",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      12,
      IConfigStorage.MarketConfig({
        assetId: "ADA",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 200000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      13,
      IConfigStorage.MarketConfig({
        assetId: "MATIC",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 200000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      14,
      IConfigStorage.MarketConfig({
        assetId: "SUI",
        maxLongPositionSize: 1000000 * 1e30,
        maxShortPositionSize: 1000000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      15,
      IConfigStorage.MarketConfig({
        assetId: "ARB",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      16,
      IConfigStorage.MarketConfig({
        assetId: "OP",
        maxLongPositionSize: 1000000 * 1e30,
        maxShortPositionSize: 1000000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      17,
      IConfigStorage.MarketConfig({
        assetId: "LTC",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      20,
      IConfigStorage.MarketConfig({
        assetId: "BNB",
        maxLongPositionSize: 1000000 * 1e30,
        maxShortPositionSize: 1000000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      21,
      IConfigStorage.MarketConfig({
        assetId: "SOL",
        maxLongPositionSize: 1000000 * 1e30,
        maxShortPositionSize: 1000000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      23,
      IConfigStorage.MarketConfig({
        assetId: "XRP",
        maxLongPositionSize: 1000000 * 1e30,
        maxShortPositionSize: 1000000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      25,
      IConfigStorage.MarketConfig({
        assetId: "LINK",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 100000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      26,
      IConfigStorage.MarketConfig({
        assetId: "CHF",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      27,
      IConfigStorage.MarketConfig({
        assetId: "DOGE",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxSkewScaleUSD: 200000000 * 1e30, maxFundingRate: 8 * 1e18 })
      }),
      true
    );
    ForkEnv.configStorage.setMarketConfig(
      28,
      IConfigStorage.MarketConfig({
        assetId: "CAD",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      29,
      IConfigStorage.MarketConfig({
        assetId: "SGD",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      30,
      IConfigStorage.MarketConfig({
        assetId: "CNH",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      31,
      IConfigStorage.MarketConfig({
        assetId: "HKD",
        maxLongPositionSize: 3000000 * 1e30,
        maxShortPositionSize: 3000000 * 1e30,
        increasePositionFeeRateBPS: 1, // 0.01%
        decreasePositionFeeRateBPS: 1, // 0.01%
        initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
        maintenanceMarginFractionBPS: 5, // MMF = 0.05%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_FOREX,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 10000000000 * 1e30, // 10B
          maxFundingRate: 1e18 // 100% per day
        })
      }),
      false
    );
    ForkEnv.configStorage.setMarketConfig(
      32,
      IConfigStorage.MarketConfig({
        assetId: "BCH",
        maxLongPositionSize: 2500000 * 1e30,
        maxShortPositionSize: 2500000 * 1e30,
        increasePositionFeeRateBPS: 7, // 0.07%
        decreasePositionFeeRateBPS: 7, // 0.07%
        initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
        maintenanceMarginFractionBPS: 50, // MMF = 0.5%
        maxProfitRateBPS: 250000, // 2500%
        assetClass: ASSET_CLASS_CRYPTO,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({
          maxSkewScaleUSD: 200000000 * 1e30, // 10B
          maxFundingRate: 8e18 // 800% per day
        })
      }),
      false
    );
    vm.stopPrank();
  }

  function _setUpOrderbookOracle() internal {
    uint256[] memory marketIndexes = new uint256[](12);
    marketIndexes[0] = 12;
    marketIndexes[1] = 13;
    marketIndexes[2] = 14;
    marketIndexes[3] = 15;
    marketIndexes[4] = 16;
    marketIndexes[5] = 17;
    marketIndexes[6] = 20;
    marketIndexes[7] = 21;
    marketIndexes[8] = 23;
    marketIndexes[9] = 25;
    marketIndexes[10] = 27;
    marketIndexes[11] = 32;
    orderbookOracle.insertMarketIndexes(marketIndexes);

    int24[] memory askDepthTicks = new int24[](12);
    askDepthTicks[0] = 149149;
    askDepthTicks[1] = 149150;
    askDepthTicks[2] = 149151;
    askDepthTicks[3] = 149152;
    askDepthTicks[4] = 149153;
    askDepthTicks[5] = 149154;
    askDepthTicks[6] = 149155;
    askDepthTicks[7] = 149156;
    askDepthTicks[8] = 149157;
    askDepthTicks[9] = 218230;
    askDepthTicks[10] = 149159;
    askDepthTicks[11] = 149160;

    int24[] memory bidDepthTicks = new int24[](12);
    bidDepthTicks[0] = 149149;
    bidDepthTicks[1] = 149150;
    bidDepthTicks[2] = 149151;
    bidDepthTicks[3] = 149152;
    bidDepthTicks[4] = 149153;
    bidDepthTicks[5] = 149154;
    bidDepthTicks[6] = 149155;
    bidDepthTicks[7] = 149156;
    bidDepthTicks[8] = 149157;
    bidDepthTicks[9] = 218230;
    bidDepthTicks[10] = 149159;
    bidDepthTicks[11] = 149160;

    int24[] memory coeffVariantTicks = new int24[](12);
    coeffVariantTicks[0] = -60708;
    coeffVariantTicks[1] = -60709;
    coeffVariantTicks[2] = -60710;
    coeffVariantTicks[3] = -60711;
    coeffVariantTicks[4] = -60712;
    coeffVariantTicks[5] = -60713;
    coeffVariantTicks[6] = -60714;
    coeffVariantTicks[7] = -60715;
    coeffVariantTicks[8] = -60716;
    coeffVariantTicks[9] = -60717;
    coeffVariantTicks[10] = -60718;
    coeffVariantTicks[11] = -60719;

    bytes32[] memory askDepths = orderbookOracle.buildUpdateData(askDepthTicks);
    bytes32[] memory bidDepths = orderbookOracle.buildUpdateData(bidDepthTicks);
    bytes32[] memory coeffVariants = orderbookOracle.buildUpdateData(coeffVariantTicks);
    orderbookOracle.setUpdater(address(this), true);
    orderbookOracle.updateData(askDepths, bidDepths, coeffVariants);
  }
}
