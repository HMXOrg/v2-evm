// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "../../base/BaseTest.sol";

import { TradeService } from "../../../src/services/TradeService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

abstract contract TradeService_Base is BaseTest {
  TradeService tradeService;

  function setUp() public virtual {
    // deploy trade service
    tradeService = new TradeService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage),
      address(mockCalculator),
      address(mockOracle)
    );
  }

  function getPositionId(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    address _subAccount = address(uint160(_account) ^ uint160(_subAccountId));
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  // todo: should integrate with increase position
  function openPosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeE30
  ) internal {
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    uint256 _absoluteSizeE30 = _sizeE30 > 0
      ? uint256(_sizeE30)
      : uint256(-_sizeE30);

    uint256 _priceE30 = 1e30;

    perpStorage.addPosition(
      _account,
      _subAccountId,
      _marketIndex,
      _positionId,
      _sizeE30,
      _absoluteSizeE30 * 9, // assume max profit is 900%
      _priceE30
    );

    IPerpStorage.GlobalMarket memory _globalMarket = perpStorage
      .getGlobalMarketById(_marketIndex);

    if (_sizeE30 > 0) {
      perpStorage.updateGlobalLongMarketById(
        _marketIndex,
        _globalMarket.longPositionSize + _absoluteSizeE30,
        _priceE30,
        _globalMarket.longOpenInterest + ((_absoluteSizeE30 * 1e30) / _priceE30)
      );
    } else {
      perpStorage.updateGlobalShortMarketById(
        _marketIndex,
        _globalMarket.shortPositionSize + _absoluteSizeE30,
        _priceE30,
        _globalMarket.shortOpenInterest +
          ((_absoluteSizeE30 * 1e30) / _priceE30)
      );
    }

    // MMR = 0.5% of position size
    mockCalculator.setMMR((_absoluteSizeE30 * 5e15) / 1e18);
  }
}
