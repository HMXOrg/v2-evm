// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MockErc20 } from "./MockErc20.sol";

contract MockLiquidityService {
  address public configStorage;
  address public perpStorage;
  address public vaultStorage;

  constructor(address _configStorage, address _perpStorage, address _vaultStorage) {
    configStorage = _configStorage;
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
  }

  function setConfigStorage(address _address) external {
    configStorage = _address;
  }

  function setPerpStorage(address _address) external {
    perpStorage = _address;
  }

  function setVaultStorage(address _address) external {
    vaultStorage = _address;
  }

  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256) {}

  function removeLiquidity(
    address /*_lpProvider*/,
    address _tokenOut,
    uint256 _amount, // amountIn
    uint256 /*_minAmount*/ //minAmountOut
  ) external returns (uint256) {
    MockErc20(_tokenOut).mint(msg.sender, _amount);

    return _amount;
  }
}
