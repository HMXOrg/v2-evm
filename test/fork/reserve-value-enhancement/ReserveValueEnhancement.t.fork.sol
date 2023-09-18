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
import { stdError } from "forge-std/StdError.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { TradeService } from "@hmx/services/TradeService.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";

contract ReserveValueEnhancement_ForkTest is ForkEnv {
  address internal constant USER = 0xC2f76d705Aaf6b4706d305f2e58F1e2e2c3950e9;
  address internal constant ORDER_EXECUTOR = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;
  uint256 internal constant MARKET_INDEX = 0;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 125699672);

    vm.startPrank(0x6409ba830719cd0fE27ccB3051DF1b399C90df4a);
    configStorage.setMarketConfig(
      MARKET_INDEX,
      IConfigStorage.MarketConfig({
        assetId: "ETH",
        maxLongPositionSize: 2_500_000 * 1e30,
        maxShortPositionSize: 2_500_000 * 1e30,
        assetClass: 0,
        maxProfitRateBPS: 9000 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 4,
        decreasePositionFeeRateBPS: 4,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 8 * 1e18, maxSkewScaleUSD: 300_000_000 * 1e30 })
      })
    );
    vm.stopPrank();

    vm.deal(USER, 1 ether);
  }

  function testRevert_WhenNotUpgraded_ArithmeticUnderflow() external {
    IPerpStorage.Position memory position = perpStorage.getPositionById(HMXLib.getPositionId(USER, MARKET_INDEX));

    assertEq(position.positionSizeE30, 1000000 * 1e30);

    vm.startPrank(USER);
    limitTradeHandler.createOrder{ value: limitTradeHandler.minExecutionFee() }(
      USER,
      0,
      MARKET_INDEX,
      -1 * 1e30,
      0,
      0,
      true,
      limitTradeHandler.minExecutionFee(),
      false,
      address(0)
    );
    vm.stopPrank();

    vm.startPrank(ORDER_EXECUTOR);
    address[] memory _accounts = new address[](1);
    _accounts[0] = USER;
    uint8[] memory _subAccountIds = new uint8[](1);
    _subAccountIds[0] = 0;
    uint256[] memory _orderIndexes = new uint256[](1);
    _orderIndexes[0] = limitTradeHandler.limitOrdersIndex(USER) - 1;
    bytes32[] memory _priceData = new bytes32[](4);
    _priceData[0] = bytes32(0x012133018d01000001fffff900000000ca8f00c2cc01273900bf1d00e1b20000);
    _priceData[1] = bytes32(0x00d5df00030e007c63fffde8ffeea10008fcffcb56ffe8b1ffe82dfffdba0000);
    _priceData[2] = bytes32(0x000dcd00a2b300a84900be5a00d2020075b600e667ffe62700ef830045620000);
    _priceData[3] = bytes32(0xfffb1eff93a4000c00000bed0000000000000000000000000000000000000000);
    bytes32[] memory _publishTimeData = new bytes32[](4);
    _publishTimeData[0] = bytes32(0x03433d03433d03433c03433c03433c00003603433c03433c00003a0000390000);
    _publishTimeData[1] = bytes32(0x00003803433c03433c03433f03433c03433c03433b03433d03433c03433b0000);
    _publishTimeData[2] = bytes32(0x03433d03433d00000000003403433d03433d00003d03433c00000203433d0000);
    _publishTimeData[3] = bytes32(0x03433c03433d03433c03433c0000000000000000000000000000000000000000);
    limitTradeHandler.executeOrders({
      _accounts: _accounts,
      _subAccountIds: _subAccountIds,
      _orderIndexes: _orderIndexes,
      _feeReceiver: payable(ORDER_EXECUTOR),
      _priceData: _priceData,
      _publishTimeData: _publishTimeData,
      _minPublishTime: 1692993608,
      _encodedVaas: keccak256("someEncodedVaas")
    });
    vm.stopPrank();

    position = perpStorage.getPositionById(HMXLib.getPositionId(USER, MARKET_INDEX));
    assertEq(position.positionSizeE30, (1000000 - 1) * 1e30);

    vm.startPrank(0x6409ba830719cd0fE27ccB3051DF1b399C90df4a);
    configStorage.setMarketConfig(
      MARKET_INDEX,
      IConfigStorage.MarketConfig({
        assetId: "ETH",
        maxLongPositionSize: 2_500_000 * 1e30,
        maxShortPositionSize: 2_500_000 * 1e30,
        assetClass: 0,
        maxProfitRateBPS: 9000 * 1e4,
        initialMarginFractionBPS: 1.1 * 1e4,
        maintenanceMarginFractionBPS: 1 * 1e4,
        increasePositionFeeRateBPS: 4,
        decreasePositionFeeRateBPS: 4,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 8 * 1e18, maxSkewScaleUSD: 300_000_000 * 1e30 })
      })
    );
    vm.stopPrank();

    vm.startPrank(0x3231C08B500bb26e0654cb0338F135CeD44d6B84);
    vm.expectRevert();
    botHandler.liquidate(USER, _priceData, _publishTimeData, 1692993608, keccak256("someEncodedVaas"));
    vm.stopPrank();
  }

  function testCorrectness_AfterUpgrade() external {
    vm.startPrank(ForkEnv.multiSig);
    Deployer.upgrade("TradeService", address(ForkEnv.proxyAdmin), address(0xcf533D0eEFB072D1BB68e201EAFc5368764daA0E));
    vm.stopPrank();

    IPerpStorage.Position memory position = perpStorage.getPositionById(HMXLib.getPositionId(USER, MARKET_INDEX));

    assertEq(position.positionSizeE30, 1000000 * 1e30);

    vm.startPrank(USER);
    limitTradeHandler.createOrder{ value: limitTradeHandler.minExecutionFee() }(
      USER,
      0,
      MARKET_INDEX,
      -1 * 1e30,
      0,
      0,
      true,
      limitTradeHandler.minExecutionFee(),
      false,
      address(0)
    );
    vm.stopPrank();

    vm.startPrank(ORDER_EXECUTOR);
    address[] memory _accounts = new address[](1);
    _accounts[0] = USER;
    uint8[] memory _subAccountIds = new uint8[](1);
    _subAccountIds[0] = 0;
    uint256[] memory _orderIndexes = new uint256[](1);
    _orderIndexes[0] = limitTradeHandler.limitOrdersIndex(USER) - 1;
    bytes32[] memory _priceData = new bytes32[](4);
    _priceData[0] = bytes32(0x012133018d01000001fffff900000000ca8f00c2cc01273900bf1d00e1b20000);
    _priceData[1] = bytes32(0x00d5df00030e007c63fffde8ffeea10008fcffcb56ffe8b1ffe82dfffdba0000);
    _priceData[2] = bytes32(0x000dcd00a2b300a84900be5a00d2020075b600e667ffe62700ef830045620000);
    _priceData[3] = bytes32(0xfffb1eff93a4000c00000bed0000000000000000000000000000000000000000);
    bytes32[] memory _publishTimeData = new bytes32[](4);
    _publishTimeData[0] = bytes32(0x03433d03433d03433c03433c03433c00003603433c03433c00003a0000390000);
    _publishTimeData[1] = bytes32(0x00003803433c03433c03433f03433c03433c03433b03433d03433c03433b0000);
    _publishTimeData[2] = bytes32(0x03433d03433d00000000003403433d03433d00003d03433c00000203433d0000);
    _publishTimeData[3] = bytes32(0x03433c03433d03433c03433c0000000000000000000000000000000000000000);
    limitTradeHandler.executeOrders({
      _accounts: _accounts,
      _subAccountIds: _subAccountIds,
      _orderIndexes: _orderIndexes,
      _feeReceiver: payable(ORDER_EXECUTOR),
      _priceData: _priceData,
      _publishTimeData: _publishTimeData,
      _minPublishTime: 1692993608,
      _encodedVaas: keccak256("someEncodedVaas")
    });
    vm.stopPrank();

    position = perpStorage.getPositionById(HMXLib.getPositionId(USER, MARKET_INDEX));
    assertEq(position.positionSizeE30, (1000000 - 1) * 1e30);

    vm.startPrank(0x6409ba830719cd0fE27ccB3051DF1b399C90df4a);
    configStorage.setMarketConfig(
      MARKET_INDEX,
      IConfigStorage.MarketConfig({
        assetId: "ETH",
        maxLongPositionSize: 2_500_000 * 1e30,
        maxShortPositionSize: 2_500_000 * 1e30,
        assetClass: 0,
        maxProfitRateBPS: 9000 * 1e4,
        initialMarginFractionBPS: 1.1 * 1e4,
        maintenanceMarginFractionBPS: 1 * 1e4,
        increasePositionFeeRateBPS: 4,
        decreasePositionFeeRateBPS: 4,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 8 * 1e18, maxSkewScaleUSD: 300_000_000 * 1e30 })
      })
    );
    vm.stopPrank();

    vm.startPrank(0x3231C08B500bb26e0654cb0338F135CeD44d6B84);
    botHandler.liquidate(USER, _priceData, _publishTimeData, 1692993608, keccak256("someEncodedVaas"));
    vm.stopPrank();
  }
}
