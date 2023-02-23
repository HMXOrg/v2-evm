// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  /**
   * Errors
   */
  error IVaultStorage_TraderTokenAlreadyExists();
  error IVaultStorage_TraderBalanceRemaining();
  error IVaultStorage_ZeroAddress();

  /**
   * Functions
   */

  function traderBalances(address _trader, address _token) external view returns (uint256 amount);

  function getTraderTokens(address _trader) external view returns (address[] memory);

  function fees(address _token) external view returns (uint256);

  function devFees(address _token) external view returns (uint256);

  function plpLiquidityUSDE30(address _token) external view returns (uint256);

  function plpTotalLiquidityUSDE30() external returns (uint256);

  function plpLiquidity(address _token) external view returns (uint256);

  function pullToken(address _token) external returns (uint256);

  function addFee(address _token, uint256 _amount) external;

  function addDevFee(address _token, uint256 _amount) external;

  function addPLPLiquidityUSDE30(address _token, uint256 amount) external;

  function addPLPTotalLiquidityUSDE30(uint256 _liquidity) external;

  function addPLPLiquidity(address _token, uint256 _amount) external;

  function withdrawFee(address _token, uint256 _amount, address _receiver) external;

  function removePLPLiquidityUSDE30(address _token, uint256 amount) external;

  function removePLPTotalLiquidityUSDE30(uint256 _liquidity) external;

  function removePLPLiquidity(address _token, uint256 _amount) external;

  function pushToken(address _token, address _to, uint256 _amount) external;

  function setTraderBalance(address _trader, address _token, uint256 _balance) external;

  function addTraderToken(address _trader, address _token) external;

  function removeTraderToken(address _trader, address _token) external;

  function transferToken(address _subAccount, address _token, uint256 _amount) external;

  function settleProfit(address _subAccount, address _token, uint256 _amount) external;
}
