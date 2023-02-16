// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  // ERRORs
  error IVaultStorage_TraderTokenAlreadyExists();
  error IVaultStorage_TraderBalanceRemaining();

  function liquidityProviderBalances(
    address _liquidityProvider,
    address _token
  ) external view returns (uint256 _amount);

  function traderBalances(
    address _trader,
    address _token
  ) external view returns (uint256 amount);

  function getTraderTokens(address _trader) external returns (address[] memory);

  function setTraderBalance(
    address _trader,
    address _token,
    uint256 _balance
  ) external;

  function addTraderToken(address _trader, address _token) external;

  function removeTraderToken(address _trader, address _token) external;

  function transferToken(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external;
}
