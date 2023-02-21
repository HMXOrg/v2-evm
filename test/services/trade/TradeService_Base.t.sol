// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "../../base/BaseTest.sol";

import { PositionTester } from "../../testers/PositionTester.sol";

import { TradeService } from "../../../src/services/TradeService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

abstract contract TradeService_Base is BaseTest {
  TradeService tradeService;

  PositionTester positionTester;

  function setUp() public virtual {
    positionTester = new PositionTester(perpStorage, mockOracle);

    // deploy services
    tradeService = new TradeService(address(perpStorage), address(vaultStorage), address(configStorage));
  }

  function getPositionId(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    address _subAccount = address(uint160(_account) ^ uint160(_subAccountId));
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  // @todo - should integrate with increase position
  function openPosition(address _account, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeE30) internal {
    tradeService.increasePosition(_account, _subAccountId, _marketIndex, _sizeE30);
    // IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(_marketIndex);
    // bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    // uint256 _absoluteSizeE30 = _sizeE30 > 0 ? uint256(_sizeE30) : uint256(-_sizeE30);

    // uint256 _priceE30 = 1e30;
    // uint256 _imr = (_absoluteSizeE30 * _marketConfig.initialMarginFraction) / 1e18;
    // uint256 _reserveValueE30 = (_imr * _marketConfig.maxProfitRate) / 1e18;

    // perpStorage.addPosition(
    //   _account,
    //   _subAccountId,
    //   _marketIndex,
    //   _positionId,
    //   _sizeE30,
    //   _reserveValueE30,
    //   _priceE30,
    //   (_imr * 1e18) / _priceE30
    // );

    // IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(_marketIndex);

    // if (_sizeE30 > 0) {
    //   perpStorage.updateGlobalLongMarketById(
    //     _marketIndex,
    //     _globalMarket.longPositionSize + _absoluteSizeE30,
    //     _priceE30,
    //     _globalMarket.longOpenInterest + ((_imr * 1e18) / _priceE30)
    //   );
    // } else {
    //   perpStorage.updateGlobalShortMarketById(
    //     _marketIndex,
    //     _globalMarket.shortPositionSize + _absoluteSizeE30,
    //     _priceE30,
    //     _globalMarket.shortOpenInterest + ((_imr * 1e18) / _priceE30)
    //   );
    // }

    // perpStorage.updateGlobalState(_reserveValueE30);

    // // MMR = 0.5% of position size
    // mockCalculator.setMMR((_absoluteSizeE30 * 5e15) / 1e18);
  }
}
