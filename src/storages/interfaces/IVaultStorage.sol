// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  // ERRORs
  error IVaultStorage_TraderTokenAlreadyExists();
  error IVaultStorage_TraderBalanceRemaining();
  error IVaultStorage_ZeroAddress();

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

  function fees(address _token) external view returns (uint256);

  function plpLiquidityUSDE30(address _token) external view returns (uint256);

  function plpTotalLiquidityUSDE30() external returns (uint256);

  function plpReserved(address _token) external view returns (uint256);

  function plpLiquidity(address _token) external view returns (uint256);

  // SETTER

  function addFee(address _token, uint256 _amount) external;

  function addPLPLiquidityUSDE30(address _token, uint256 amount) external;

  function addPLPTotalLiquidityUSDE30(uint256 _liquidity) external;

  function addPLPLiquidity(address _token, uint256 _amount) external;

  function withdrawFee(
    address _token,
    uint256 _amount,
    address _receiver
  ) external;

  function removePLPLiquidityUSDE30(address _token, uint256 amount) external;

  function removePLPTotalLiquidityUSDE30(uint256 _liquidity) external;

  function removePLPLiquidity(address _token, uint256 _amount) external;

  function removePLPReserved(address _token, uint256 _amount) external;

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
