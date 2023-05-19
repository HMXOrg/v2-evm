// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

contract MockAccountAbstraction {
  address public owner;
  address public entryPoint;

  constructor(address _entryPoint) {
    owner = msg.sender;
    entryPoint = _entryPoint;
  }

  function setOwner(address _owner) external {
    owner = _owner;
  }

  function setEntryPoint(address _entryPoint) external {
    entryPoint = _entryPoint;
  }

  function _requireFromEntryPointOrOwner() internal view {
    require(msg.sender == address(entryPoint) || msg.sender == owner, "account: not Owner or EntryPoint");
  }

  function createOrder(
    address target,
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
    _requireFromEntryPointOrOwner();
    ILimitTradeHandler(target).createOrder{ value: msg.value }(
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
