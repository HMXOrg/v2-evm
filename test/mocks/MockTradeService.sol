// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ITradeService } from "../../src/services/interfaces/ITradeService.sol";

contract MockTradeService is ITradeService {
  address public configStorage;
  address public perpStorage;

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
  ) external {}

  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease
  ) external {}
}
