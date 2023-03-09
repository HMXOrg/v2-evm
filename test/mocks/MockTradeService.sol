// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";

contract MockTradeService is ITradeService {
  struct IncreasePositionInputs {
    address _primaryAccount;
    uint8 _subAccountId;
    uint256 _marketIndex;
    int256 _sizeDelta;
    uint256 _limitPriceE30;
  }

  struct DecreasePositionInputs {
    address _account;
    uint8 _subAccountId;
    uint256 _marketIndex;
    uint256 _positionSizeE30ToDecrease;
    // @todo - support take profit token
    // address _tpToken;
    uint256 _limitPriceE30;
  }

  address public configStorage;
  address public perpStorage;

  uint256 public increasePositionCallCount;
  uint256 public decreasePositionCallCount;
  IncreasePositionInputs[] public increasePositionCalls;
  DecreasePositionInputs[] public decreasePositionCalls;

  function setConfigStorage(address _address) external {
    configStorage = _address;
  }

  function setPerpStorage(address _address) external {
    perpStorage = _address;
  }

  function increasePosition(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _limitPriceE30
  ) external {
    increasePositionCallCount++;
    increasePositionCalls.push(
      IncreasePositionInputs({
        _primaryAccount: _primaryAccount,
        _subAccountId: _subAccountId,
        _marketIndex: _marketIndex,
        _sizeDelta: _sizeDelta,
        _limitPriceE30: _limitPriceE30
      })
    );
  }

  function decreasePosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address /*_tpToken*/,
    uint256 _limitPriceE30
  ) external {
    decreasePositionCallCount++;
    decreasePositionCalls.push(
      DecreasePositionInputs({
        _account: _account,
        _subAccountId: _subAccountId,
        _marketIndex: _marketIndex,
        _positionSizeE30ToDecrease: _positionSizeE30ToDecrease,
        _limitPriceE30: _limitPriceE30
      })
    );
  }

  function forceClosePosition(
    address /*_account*/,
    uint8 /*_subAccountId*/,
    uint256 /*_marketIndex*/,
    address /*_tpToken*/
  ) external returns (bool _isMaxProfit, bool _isProfit, uint256 _delta) {
    decreasePositionCallCount++;
    return (false, false, 0);
  }

  function validateMaxProfit(bool isMaxProfit) external view {}

  function validateDeleverage() external view {}

  function validateMarketDelisted(uint256 _marketIndex) external view {}

  function getNextFundingRate(
    uint256 /*_marketIndex*/,
    uint256 /*_price*/
  ) external pure returns (int256 fundingRate, int256 fundingRateLong, int256 fundingRateShort) {
    return (0, 0, 0);
  }

  function getDelta(
    uint256 /*_size*/,
    bool /*_isLong*/,
    uint256 /*_markPrice*/,
    uint256 /*_averagePrice*/
  ) external pure returns (bool, uint256) {
    return (false, 0);
  }
}
