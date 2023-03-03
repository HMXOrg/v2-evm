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

  function plpLiquidityDebtUSDE30() external view returns (uint256);

  function traderBalances(address _trader, address _token) external view returns (uint256 amount);

  function getTraderTokens(address _trader) external view returns (address[] memory);

  function fees(address _token) external view returns (uint256);

  function fundingFee(address _token) external view returns (uint256);

  function devFees(address _token) external view returns (uint256);

  function plpLiquidityUSDE30(address _token) external view returns (uint256);

  function plpLiquidity(address _token) external view returns (uint256);

  function pullToken(address _token) external returns (uint256);

  function addFee(address _token, uint256 _amount) external;

  function addDevFee(address _token, uint256 _amount) external;

  function addPLPLiquidityUSDE30(address _token, uint256 amount) external;

  function addPLPLiquidity(address _token, uint256 _amount) external;

  function withdrawFee(address _token, uint256 _amount, address _receiver) external;

  function removePLPLiquidityUSDE30(address _token, uint256 amount) external;

  function removePLPLiquidity(address _token, uint256 _amount) external;

  function pushToken(address _token, address _to, uint256 _amount) external;

  function setTraderBalance(address _trader, address _token, uint256 _balance) external;

  function addTraderToken(address _trader, address _token) external;

  function removeTraderToken(address _trader, address _token) external;

  function transferToken(address _subAccount, address _token, uint256 _amount) external;

  function addFundingFee(address _token, uint256 _amount) external;

  function removeFundingFee(address _token, uint256 _amount) external;

  function addPlpLiquidityDebtUSDE30(uint256 _value) external;

  function removePlpLiquidityDebtUSDE30(uint256 _value) external;

  function pullPLPLiquidity(address _token) external view returns (uint256);

  function increaseTraderBalance(address _subAccount, address _token, uint256 _amount) external;

  function decreaseTraderBalance(address _subAccount, address _token, uint256 _amount) external;

  function payPlp(address _trader, address _token, uint256 _amount) external;

  function collectMarginFee(
    address _subAccount,
    address _token,
    uint256 feeTokenAmount,
    uint256 devFeeTokenAmount,
    uint256 traderBalance
  ) external;

  function collectFundingFee(
    address subAccount,
    address underlyingToken,
    uint256 collectFeeTokenAmount,
    uint256 traderBalance
  ) external;

  function repayFundingFee(
    address subAccount,
    address underlyingToken,
    uint256 repayFeeTokenAmount,
    uint256 traderBalance
  ) external;

  function borrowFundingFeeFromPLP(
    address subAccount,
    address underlyingToken,
    uint256 borrowFeeTokenAmount,
    uint256 borrowFeeTokenValue,
    uint256 traderBalance
  ) external;

  function repayFundingFeeToPLP(
    address subAccount,
    address underlyingToken,
    uint256 repayFeeTokenAmount,
    uint256 repayFeeTokenValue,
    uint256 traderBalance
  ) external;
}
