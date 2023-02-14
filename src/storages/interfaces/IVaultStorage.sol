// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  function liquidityProviderBalances(
    address _liquidityProvider,
    address _token
  ) external view returns (uint _amount);

  function traderBalances(
    address _trader,
    address _token
  ) external view returns (uint amount);

  function getTraderTokens(
    address _trader
  ) external view returns (address[] memory);

  function getLiquidityProviderTokens(
    address _token
  ) external view returns (address[] memory);

  function getTotalLiquidityTokens(
    address _token
  ) external view returns (uint256);

  function addFee(address _token, uint256 _amount) external;

  function setLiquidityProviderBalances(
    address _lpProvider,
    address _token,
    uint256 _amount
  ) external;

  function setLiquidityProviderTokens(
    address _lpProvider,
    address _token
  ) external;
}
