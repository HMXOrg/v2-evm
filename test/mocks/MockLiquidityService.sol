// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract MockLiquidityService {
  address public configStorage;
  address public perpStorage;
  address public vaultStorage;

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
    address _lpProvider,
    address _tokenOut,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256) {}
}
