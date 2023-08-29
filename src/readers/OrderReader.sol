// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";

contract OrderReader {
  IConfigStorage public immutable configStorage;
  ILimitTradeHandler public immutable limitTradeHandler;
  OracleMiddleware public immutable oracleMiddleware;
  IPerpStorage public immutable perpStorage;

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
    uint128 ordersCount;
    uint64 startIndex;
    uint64 endIndex;
  }

  function getExecutableOrders(
    uint64 _limit,
    uint64 _offset,
    bytes32[] memory _assetIds,
    uint64[] memory _prices
  ) external view returns (ILimitTradeHandler.LimitOrder[] memory) {
    ExecutableOrderVars memory vars;
    // get active orders
    vars.orders = limitTradeHandler.getLimitActiveOrders(_limit, _offset);
    vars.ordersCount = uint128(limitTradeHandler.activeLimitOrdersCount());
    vars.startIndex = _offset;
    vars.endIndex = _offset + _limit;
    if (vars.startIndex > vars.ordersCount) return vars.executableOrders;
    if (vars.endIndex > vars.ordersCount) {
      vars.endIndex = uint64(vars.ordersCount);
    }
    // get merket configs
    vars.marketConfigs = configStorage.getMarketConfigs();
    uint256 len = vars.marketConfigs.length;
    vars.isInValidMarket = new bool[](len);
    for (uint256 i; i < len; i++) {
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
    }

    vars.executableOrders = new ILimitTradeHandler.LimitOrder[](vars.endIndex - vars.startIndex);
    ILimitTradeHandler.LimitOrder memory _order;
    address _subAccount;
    bytes32 _positionId;
    IPerpStorage.Position memory _position;
    len = vars.orders.length;
    for (uint256 i; i < len; i++) {
      _order = vars.orders[i];
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
          _subAccount = _getSubAccount(_order.account, _order.subAccountId);
          _positionId = _getPositionId(_subAccount, _order.marketIndex);
          _position = perpStorage.getPositionById(_positionId);
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
    uint64[] memory _prices
  ) internal pure returns (uint256) {
    uint256 _len = _assetIds.length;
    for (uint256 i; i < _len; ) {
      if (_assetIds[i] == _assetId) {
        return uint256(_prices[i]) * 1e22;
      }
      unchecked {
        ++i;
      }
    }
    return 0;
  }
}
