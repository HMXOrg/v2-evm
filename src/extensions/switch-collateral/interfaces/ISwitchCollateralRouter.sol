// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISwitchCollateralRouter {
  function execute(uint256 _amount, address[] calldata _path) external returns (uint256);
}
