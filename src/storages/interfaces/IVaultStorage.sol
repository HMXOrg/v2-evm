// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  function liquidityProviderBalances(
    address liquidityProvider,
    address token
  ) external view returns (uint amount);

  function liquidityProviderTokens(
    address liquidityProvider,
    address token
  ) external view returns (uint amount);

  function traderBalances(
    address trader,
    address token
  ) external view returns (uint amount);

  function traderTokens(
    address trader,
    address token
  ) external view returns (uint amount);
}
