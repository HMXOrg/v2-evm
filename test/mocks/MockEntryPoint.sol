// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockAccountAbstraction } from "./MockAccountAbstraction.sol";

contract MockEntryPoint {
  function createOrder(
    address account,
    address target,
    address mainAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    uint256 _acceptablePrice,
    bool _triggerAboveThreshold,
    uint256 _executionFee,
    bool _reduceOnly,
    address _tpToken
  ) external payable {
    MockAccountAbstraction(account).createOrder{ value: msg.value }(
      target,
      mainAccount,
      _subAccountId,
      _marketIndex,
      _sizeDelta,
      _triggerPrice,
      _acceptablePrice,
      _triggerAboveThreshold,
      _executionFee,
      _reduceOnly,
      _tpToken
    );
  }
}
