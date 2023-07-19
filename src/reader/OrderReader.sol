// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// interfaces
import { ConfigStorage } from "../storages/ConfigStorage.sol";
import { PerpStorage } from "../storages/PerpStorage.sol";
import { LimitTradeHandler } from "../handlers/LimitTradeHandler.sol";
import { OracleMiddleware } from "../oracles/OracleMiddleware.sol";

import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { ILimitTradeHandler } from "../handlers/interfaces/ILimitTradeHandler.sol";
import { IOracleMiddleware } from "../oracles/interfaces/IOracleMiddleware.sol";

contract OrderReader {
  IConfigStorage public configStorage;
  ILimitTradeHandler public limitTradeHandler;
  OracleMiddleware public oracleMiddleware;
  IPerpStorage public perpStorage;

  constructor(address _configStorage, address _perpStorage, address _oracleMiddleware, address _limitTradeHandler) {
    configStorage = IConfigStorage(_configStorage);
    perpStorage = IPerpStorage(_perpStorage);
    limitTradeHandler = ILimitTradeHandler(_limitTradeHandler);
    oracleMiddleware = OracleMiddleware(_oracleMiddleware);
  }

  struct ExecutableOrderVars {
    ILimitTradeHandler.LimitOrder[] orders;
    bool[] isInValidMarket;
    ILimitTradeHandler.LimitOrder[] executableOrders;
    IConfigStorage.MarketConfig[] marketConfigs;
    uint256 ordersCount;
    uint256 startIndex;
    uint256 endIndex;
  }

  function getExecutableOrders(
    uint256 _limit,
    uint256 _offset,
    bytes32[] memory _assetIds,
    uint256[] memory _prices
  ) external view returns (ILimitTradeHandler.LimitOrder[] memory) {
    ExecutableOrderVars memory vars;
    // get active orders
    vars.orders = limitTradeHandler.getLimitActiveOrders(_limit, _offset);
    vars.ordersCount = limitTradeHandler.activeLimitOrdersCount();
    vars.startIndex = _offset;
    vars.endIndex = _offset + _limit;
    if (vars.startIndex > vars.ordersCount) return vars.executableOrders;
    if (vars.endIndex > vars.ordersCount) {
      vars.endIndex = vars.ordersCount;
    }
    // get merket configs
    vars.marketConfigs = configStorage.getMarketConfigs();
    uint256 len = vars.marketConfigs.length;
    vars.isInValidMarket = new bool[](len);
    for (uint256 i = 0; i < len; i++) {
      // check active merket
      if (!vars.marketConfigs[i].active) {
        vars.isInValidMarket[i] = true;
        continue;
      }
      // check merket status
      if (oracleMiddleware.marketStatus(vars.marketConfigs[i].assetId) != 2) {
        vars.isInValidMarket[i] = true;
        continue;
      }
      vars.isInValidMarket[i] = false;
    }

    vars.executableOrders = new ILimitTradeHandler.LimitOrder[](vars.endIndex - vars.startIndex);
    len = vars.orders.length;
    for (uint256 i = 0; i < len; i++) {
      ILimitTradeHandler.LimitOrder memory _order = vars.orders[i];
      {
        if (vars.isInValidMarket[_order.marketIndex]) {
          continue;
        }
        // validate price
        if (
          !_validateExecutableOrder(
            _order.triggerPrice,
            _order.triggerAboveThreshold,
            _getPrice(vars.marketConfigs[_order.marketIndex].assetId, _assetIds, _prices)
          )
        ) {
          continue;
        }
        // check Tp/Sl order
        if (_isTpSlOrder(_order)) {
          address _subAccount = _getSubAccount(_order.account, _order.subAccountId);
          bytes32 _positionId = _getPositionId(_subAccount, _order.marketIndex);
          IPerpStorage.Position memory _position = perpStorage.getPositionById(_positionId);
          if (_isPositionClose(_position)) {
            continue;
          }
        }
      }
      vars.executableOrders[i] = _order;
    }

    return vars.executableOrders;
  }

  function _validateExecutableOrder(
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    uint256 _price
  ) internal pure returns (bool) {
    return _triggerAboveThreshold ? _price > _triggerPrice : _price < _triggerPrice;
  }

  function _isTpSlOrder(ILimitTradeHandler.LimitOrder memory _order) internal pure returns (bool) {
    return _order.reduceOnly && (_order.sizeDelta == type(int256).max || _order.sizeDelta == type(int256).min);
  }

  function _isPositionClose(IPerpStorage.Position memory _position) internal pure returns (bool) {
    return _position.primaryAccount == address(0);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address _subAccount) {
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function _getPositionId(address _subAccount, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  function _getPrice(
    bytes32 _assetId,
    bytes32[] memory _assetIds,
    uint256[] memory _prices
  ) internal pure returns (uint256) {
    uint256 _len = _assetIds.length;
    for (uint256 i; i < _len; ) {
      if (_assetIds[i] == _assetId) {
        return _prices[i];
      }
      unchecked {
        ++i;
      }
    }
    return 0;
  }
}
