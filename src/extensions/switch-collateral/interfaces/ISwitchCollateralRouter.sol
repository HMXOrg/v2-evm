// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IDexter } from "@hmx/extensions/dexters/interfaces/IDexter.sol";

interface ISwitchCollateralRouter {
  function execute(uint256 _amount, address[] calldata _path) external returns (uint256);

  function dexterOf(address _tokenIn, address _tokenOut) external view returns (IDexter _dexter);

  function setDexterOf(address _tokenIn, address _tokenOut, address _switchCollateralExt) external;
}
