// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  function liquidityProviderBalances(
    address _liquidityProvider,
    address _token
  ) external view returns (uint _amount);

  function liquidityProviderTokens(
    address _liquidityProvider,
    address _token
  ) external view returns (address[] memory _tokens);

  function traderBalances(
    address _trader,
    address _token
  ) external view returns (uint amount);

  function traderTokens(
    address _trader,
    address _token
  ) external view returns (address[] memory _tokens);
}
