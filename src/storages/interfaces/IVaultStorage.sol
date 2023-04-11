// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  /**
   * Errors
   */
  error IVaultStorage_NotWhiteListed();
  error IVaultStorage_TraderTokenAlreadyExists();
  error IVaultStorage_TraderBalanceRemaining();
  error IVaultStorage_ZeroAddress();
  error IVaultStorage_PLPBalanceRemaining();
  error IVaultStorage_Forbidden();
  error IVaultStorage_TargetNotContract();

  /**
   * Functions
   */
  function totalAmount(address _token) external returns (uint256);

  function plpLiquidityDebtUSDE30() external view returns (uint256);

  function traderBalances(address _trader, address _token) external view returns (uint256 amount);

  function getTraderTokens(address _trader) external view returns (address[] memory);

  function protocolFees(address _token) external view returns (uint256);

  function fundingFeeReserve(address _token) external view returns (uint256);

  function devFees(address _token) external view returns (uint256);

  function plpLiquidity(address _token) external view returns (uint256);

  function pullToken(address _token) external returns (uint256);

  function addFee(address _token, uint256 _amount) external;

  function addPLPLiquidity(address _token, uint256 _amount) external;

  function withdrawFee(address _token, uint256 _amount, address _receiver) external;

  function removePLPLiquidity(address _token, uint256 _amount) external;

  function pushToken(address _token, address _to, uint256 _amount) external;

  function addFundingFee(address _token, uint256 _amount) external;

  function removeFundingFee(address _token, uint256 _amount) external;

  function addPlpLiquidityDebtUSDE30(uint256 _value) external;

  function removePlpLiquidityDebtUSDE30(uint256 _value) external;

  function increaseTraderBalance(address _subAccount, address _token, uint256 _amount) external;

  function decreaseTraderBalance(address _subAccount, address _token, uint256 _amount) external;

  function payPlp(address _trader, address _token, uint256 _amount) external;

  function setServiceExecutors(address _executorAddress, bool _isServiceExecutor) external;

  function borrowFundingFeeFromPlpToTrader(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount,
    uint256 _fundingFeeValue
  ) external;

  function repayFundingFeeDebtFromTraderToPlp(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount,
    uint256 _fundingFeeValue
  ) external;

  function cook(address _target, address _token, bytes calldata _callData) external returns (bytes memory);
}
