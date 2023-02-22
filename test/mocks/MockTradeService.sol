// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ITradeService } from "../../src/services/interfaces/ITradeService.sol";

contract MockTradeService is ITradeService {
  struct IncreasePositionInputs {
    address _primaryAccount;
    uint256 _subAccountId;
    uint256 _marketIndex;
    int256 _sizeDelta;
  }

  struct DecreasePositionInputs {
    address _account;
    uint256 _subAccountId;
    uint256 _marketIndex;
    uint256 _positionSizeE30ToDecrease;
    // @todo - support take profit token
    // address _tpToken;
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
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta
  ) external {
    increasePositionCallCount++;
    increasePositionCalls.push(
      IncreasePositionInputs({
        _primaryAccount: _primaryAccount,
        _subAccountId: _subAccountId,
        _marketIndex: _marketIndex,
        _sizeDelta: _sizeDelta
      })
    );
  }

  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken
  ) external {
    decreasePositionCallCount++;
    decreasePositionCalls.push(
      DecreasePositionInputs({
        _account: _account,
        _subAccountId: _subAccountId,
        _marketIndex: _marketIndex,
        _positionSizeE30ToDecrease: _positionSizeE30ToDecrease
      })
    );
  }
}
