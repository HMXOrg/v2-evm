// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// openzepline
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";

contract TradeService is ITradeService {
  using SafeCast for int256;

  // events
  event LogDecreasePosition();

  // state
  address perpStorage;
  address vaultStorage;
  address configStorage;
  address calculator;

  constructor(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _calculator
  ) {
    // todo: sanity check
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = _calculator;
  }

  // todo: rewrite description
  /// @notice decrease trader position
  /// @param _account - address
  /// @param _subAccountId - address
  /// @param _marketId - market id
  /// @param _positionSizeE30ToDecrease - position size to decrease,
  ///                           if target position is Long position _size should be position,
  ///                           otherwise _size should be negative
  /// @param _priceE30 - asset price in USD e30
  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketId,
    int256 _positionSizeE30ToDecrease,
    uint256 _priceE30
  ) external {
    // prepare
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigById(_marketId);

    address _subAccount = _getSubAccount(_account, _subAccountId);
    bytes32 _positionId = _getPositionId(_subAccount, _marketId);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_positionId);

    // pre validation
    // todo: check market status
    // if position size is 0 means this position is already closed
    int256 _positionSize = _position.positionSizeE30;
    if (_positionSize == 0) {
      revert ITradeService_PositionAlreadyClosed();
    }

    if (_positionSizeE30ToDecrease > _positionSize) {
      revert ITradeService_DecreaseTooHighPositionSize();
    }

    // check sub account is healty
    uint256 _subAccountEquity = ICalculator(calculator).getEquity(_subAccount);
    // absolute position size
    uint256 _absPositionSize = (
      _positionSize > 0 ? _positionSize : -_positionSize
    ).toUint256();
    // maintenanceMarginFraction is 1e18, mmr = position size * maintenance margin fraction
    uint256 _mmr = (_absPositionSize *
      _marketConfig.maintenanceMarginFraction) / 1e18;

    // if sub account equity < MMR, then trader couln't decrease position
    if (_subAccountEquity < _mmr) {
      revert ITradeService_SubAccountEquityIsUnderMMR();
    }

    // todo: update funding & borrowing fee rate
    // todo: calculate trading, borrowing and funding fee
    // todo: collect fee
    // todo: calculate USD out

    // update position state
    int256 _newPositionSize = _positionSize - _positionSizeE30ToDecrease;
    // absolute new position size
    uint256 _absNewPositionSize = (
      _positionSize > 0 ? _positionSize : -_positionSize
    ).toUint256();
    _position = IPerpStorage(perpStorage).updatePositionById(
      _positionId,
      _newPositionSize, // _newPositionSizeE30
      (_absNewPositionSize * _marketConfig.maxProfitRate) / 1e18, // _newReserveValueE30
      _newPositionSize == 0 ? 0 : _position.avgEntryPriceE30 // _newAvgPriceE30
    );
    // todo: update market global state

    // todo: settle profit & loss
    // post validate
  }

  // todo: add description
  function _getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  // todo: add description
  function _getPositionId(
    address _account,
    uint256 _marketId
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketId));
  }
}
