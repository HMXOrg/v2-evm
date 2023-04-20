// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// interfaces
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IVaultStorage } from "./interfaces/IVaultStorage.sol";

import { Owned } from "@hmx/base/Owned.sol";

/// @title VaultStorage
/// @notice storage contract to do accounting for token, and also hold physical tokens
contract VaultStorage is Owned, ReentrancyGuardUpgradeable, IVaultStorage {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * Events
   */
  event LogSetTraderBalance(address indexed trader, address token, uint balance);
  event SetServiceExecutor(address indexed executorAddress, bool isServiceExecutor);

  /**
   * States
   */
  mapping(address => uint256) public totalAmount; //token => tokenAmount
  mapping(address => uint256) public plpLiquidity; // token => PLPTokenAmount
  mapping(address => uint256) public protocolFees; // protocol fee in token unit

  uint256 public plpLiquidityDebtUSDE30; // USD dept accounting when fundingFee is not enough to repay to trader
  mapping(address => uint256) public fundingFeeReserve; // sum of realized funding fee amount

  mapping(address => uint256) public devFees;

  mapping(address => uint256) public tradingFeeDebt;
  mapping(address => uint256) public borrowingFeeDebt;
  mapping(address => uint256) public fundingFeeDebt;
  mapping(address => uint256) public lossDebt;

  uint256 public globalTradingFeeDebt;
  uint256 public globalBorrowingFeeDebt;
  uint256 public globalFundingFeeDebt;
  uint256 public globalLossDebt;

  // trader address (with sub-account) => token => amount
  mapping(address => mapping(address => uint256)) public traderBalances;
  // mapping(address => address[]) public traderTokens;
  mapping(address => address[]) public traderTokens;
  mapping(address => bool) public serviceExecutors;

  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    if (!serviceExecutors[msg.sender]) revert IVaultStorage_NotWhiteListed();
    _;
  }

  /**
   * Core Functions
   */

  function validateAddTraderToken(address _trader, address _token) external view {
    _validateAddTraderToken(_trader, _token);
  }

  function validateRemoveTraderToken(address _trader, address _token) external view {
    _validateRemoveTraderToken(_trader, _token);
  }

  /**
   * Getters
   */

  function getTraderTokens(address _subAccount) external view returns (address[] memory) {
    return traderTokens[_subAccount];
  }

  /**
   * ERC20 interaction functions
   */

  function pullToken(address _token) external returns (uint256) {
    uint256 prevBalance = totalAmount[_token];
    uint256 nextBalance = IERC20Upgradeable(_token).balanceOf(address(this));

    totalAmount[_token] = nextBalance;
    return nextBalance - prevBalance;
  }

  function pushToken(address _token, address _to, uint256 _amount) external nonReentrant onlyWhitelistedExecutor {
    IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    totalAmount[_token] = IERC20Upgradeable(_token).balanceOf(address(this));
  }

  /**
   * Setters
   */

  function setServiceExecutors(address _executorAddress, bool _isServiceExecutor) external nonReentrant onlyOwner {
    serviceExecutors[_executorAddress] = _isServiceExecutor;
    emit SetServiceExecutor(_executorAddress, _isServiceExecutor);
  }

  function addFee(address _token, uint256 _amount) external onlyWhitelistedExecutor {
    protocolFees[_token] += _amount;
  }

  function addFundingFee(address _token, uint256 _amount) external onlyWhitelistedExecutor {
    fundingFeeReserve[_token] += _amount;
  }

  function removeFundingFee(address _token, uint256 _amount) external onlyWhitelistedExecutor {
    fundingFeeReserve[_token] -= _amount;
  }

  function addPlpLiquidityDebtUSDE30(uint256 _value) external onlyWhitelistedExecutor {
    plpLiquidityDebtUSDE30 += _value;
  }

  function removePlpLiquidityDebtUSDE30(uint256 _value) external onlyWhitelistedExecutor {
    plpLiquidityDebtUSDE30 -= _value;
  }

  function addPLPLiquidity(address _token, uint256 _amount) external onlyWhitelistedExecutor {
    plpLiquidity[_token] += _amount;
  }

  function withdrawFee(address _token, uint256 _amount, address _receiver) external onlyWhitelistedExecutor {
    if (_receiver == address(0)) revert IVaultStorage_ZeroAddress();
    protocolFees[_token] -= _amount;
    IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
  }

  function removePLPLiquidity(address _token, uint256 _amount) external onlyWhitelistedExecutor {
    if (plpLiquidity[_token] < _amount) revert IVaultStorage_PLPBalanceRemaining();
    plpLiquidity[_token] -= _amount;
  }

  /// @notice increase sub-account collateral
  /// @param _subAccount - sub account
  /// @param _token - collateral token to increase
  /// @param _amount - amount to increase
  function increaseTraderBalance(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external onlyWhitelistedExecutor {
    _increaseTraderBalance(_subAccount, _token, _amount);
  }

  /// @notice decrease sub-account collateral
  /// @param _subAccount - sub account
  /// @param _token - collateral token to increase
  /// @param _amount - amount to increase
  function decreaseTraderBalance(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external onlyWhitelistedExecutor {
    _deductTraderBalance(_subAccount, _token, _amount);
  }

  /// @notice Pays the PLP for providing liquidity with the specified token and amount.
  /// @param _trader The address of the trader paying the PLP.
  /// @param _token The address of the token being used to pay the PLP.
  /// @param _amount The amount of the token being used to pay the PLP.
  function payPlp(address _trader, address _token, uint256 _amount) external onlyWhitelistedExecutor {
    // Increase the PLP's liquidity for the specified token
    plpLiquidity[_token] += _amount;

    // Decrease the trader's balance for the specified token
    _deductTraderBalance(_trader, _token, _amount);
  }

  function transfer(address _token, address _from, address _to, uint256 _amount) external onlyWhitelistedExecutor {
    _deductTraderBalance(_from, _token, _amount);
    _increaseTraderBalance(_to, _token, _amount);
  }

  function payTradingFee(
    address _trader,
    address _token,
    uint256 _devFeeAmount,
    uint256 _protocolFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from trader balance
    _deductTraderBalance(_trader, _token, _devFeeAmount + _protocolFeeAmount);

    // Increase the amount to devFees and protocolFees
    devFees[_token] += _devFeeAmount;
    protocolFees[_token] += _protocolFeeAmount;
  }

  function payBorrowingFee(
    address _trader,
    address _token,
    uint256 _devFeeAmount,
    uint256 _plpFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from trader balance
    _deductTraderBalance(_trader, _token, _devFeeAmount + _plpFeeAmount);

    // Increase the amount to devFees and plpLiquidity
    devFees[_token] += _devFeeAmount;
    plpLiquidity[_token] += _plpFeeAmount;
  }

  function payFundingFeeFromTraderToPlp(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from trader balance
    _deductTraderBalance(_trader, _token, _fundingFeeAmount);

    // Increase the amount to plpLiquidity
    plpLiquidity[_token] += _fundingFeeAmount;
  }

  function payFundingFeeFromPlpToTrader(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from plpLiquidity
    plpLiquidity[_token] -= _fundingFeeAmount;

    // Increase the amount to trader
    _increaseTraderBalance(_trader, _token, _fundingFeeAmount);
  }

  function payTraderProfit(
    address _trader,
    address _token,
    uint256 _totalProfitAmount,
    uint256 _settlementFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from plpLiquidity
    plpLiquidity[_token] -= _totalProfitAmount;

    protocolFees[_token] += _settlementFeeAmount;
    _increaseTraderBalance(_trader, _token, _totalProfitAmount - _settlementFeeAmount);
  }

  function _increaseTraderBalance(address _trader, address _token, uint256 _amount) internal {
    if (_amount == 0) return;

    if (traderBalances[_trader][_token] == 0) {
      _addTraderToken(_trader, _token);
    }
    traderBalances[_trader][_token] += _amount;
  }

  function _deductTraderBalance(address _trader, address _token, uint256 _amount) internal {
    if (_amount == 0) return;

    traderBalances[_trader][_token] -= _amount;
    if (traderBalances[_trader][_token] == 0) {
      _removeTraderToken(_trader, _token);
    }
  }

  function convertFundingFeeReserveWithPLP(
    address _convertToken,
    address _targetToken,
    uint256 _convertAmount,
    uint256 _targetAmount
  ) external onlyWhitelistedExecutor {
    // Deduct convert token amount from funding fee reserve
    fundingFeeReserve[_convertToken] -= _convertAmount;

    // Increase convert token amount to PLP
    plpLiquidity[_convertToken] += _convertAmount;

    // Deduct target token amount from PLP
    plpLiquidity[_targetToken] -= _targetAmount;

    // Deduct convert token amount from funding fee reserve
    fundingFeeReserve[_targetToken] += _targetAmount;
  }

  function withdrawSurplusFromFundingFeeReserveToPLP(
    address _token,
    uint256 _fundingFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from funding fee reserve
    fundingFeeReserve[_token] -= _fundingFeeAmount;

    // Increase the amount to PLP
    plpLiquidity[_token] += _fundingFeeAmount;
  }

  function payFundingFeeFromTraderToFundingFeeReserve(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from trader balance
    _deductTraderBalance(_trader, _token, _fundingFeeAmount);

    // Increase the amount to fundingFee
    fundingFeeReserve[_token] += _fundingFeeAmount;
  }

  function payFundingFeeFromFundingFeeReserveToTrader(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount
  ) external onlyWhitelistedExecutor {
    // Deduct amount from fundingFee
    fundingFeeReserve[_token] -= _fundingFeeAmount;

    // Increase the amount to trader
    _increaseTraderBalance(_trader, _token, _fundingFeeAmount);
  }

  function repayFundingFeeDebtFromTraderToPlp(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount,
    uint256 _fundingFeeValue
  ) external onlyWhitelistedExecutor {
    // Deduct amount from trader balance
    _deductTraderBalance(_trader, _token, _fundingFeeAmount);

    // Add token amounts that PLP received
    plpLiquidity[_token] += _fundingFeeAmount;

    // Remove debt value on PLP as received
    plpLiquidityDebtUSDE30 -= _fundingFeeValue;
  }

  function borrowFundingFeeFromPlpToTrader(
    address _trader,
    address _token,
    uint256 _fundingFeeAmount,
    uint256 _fundingFeeValue
  ) external onlyWhitelistedExecutor {
    // Deduct token amounts from PLP
    plpLiquidity[_token] -= _fundingFeeAmount;

    // Increase the amount to trader
    _increaseTraderBalance(_trader, _token, _fundingFeeAmount);

    // Add debt value on PLP
    plpLiquidityDebtUSDE30 += _fundingFeeValue;
  }

  function addTradingFeeDebt(address _trader, uint256 _tradingFeeDebt) external {
    tradingFeeDebt[_trader] += _tradingFeeDebt;
    globalTradingFeeDebt += _tradingFeeDebt;
  }

  function addBorrowingFeeDebt(address _trader, uint256 _borrowingFeeDebt) external {
    borrowingFeeDebt[_trader] += _borrowingFeeDebt;
    globalBorrowingFeeDebt += _borrowingFeeDebt;
  }

  function addFundingFeeDebt(address _trader, uint256 _fundingFeeDebt) external {
    fundingFeeDebt[_trader] += _fundingFeeDebt;
    globalFundingFeeDebt += _fundingFeeDebt;
  }

  function addLossDebt(address _trader, uint256 _lossDebt) external {
    lossDebt[_trader] += _lossDebt;
    globalLossDebt += _lossDebt;
  }

  function subTradingFeeDebt(address _trader, uint256 _tradingFeeDebt) external {
    tradingFeeDebt[_trader] -= _tradingFeeDebt;
    globalTradingFeeDebt -= _tradingFeeDebt;
  }

  function subBorrowingFeeDebt(address _trader, uint256 _borrowingFeeDebt) external {
    borrowingFeeDebt[_trader] -= _borrowingFeeDebt;
    globalBorrowingFeeDebt -= _borrowingFeeDebt;
  }

  function subFundingFeeDebt(address _trader, uint256 _fundingFeeDebt) external {
    fundingFeeDebt[_trader] -= _fundingFeeDebt;
    globalFundingFeeDebt -= _fundingFeeDebt;
  }

  function subLossDebt(address _trader, uint256 _lossDebt) external {
    lossDebt[_trader] -= _lossDebt;
    globalLossDebt -= _lossDebt;
  }

  /**
   * Private Functions
   */

  function _addTraderToken(address _trader, address _token) private {
    _validateAddTraderToken(_trader, _token);
    traderTokens[_trader].push(_token);
  }

  function _removeTraderToken(address _trader, address _token) private {
    _validateRemoveTraderToken(_trader, _token);

    address[] storage traderToken = traderTokens[_trader];
    uint256 tokenLen = traderToken.length;
    uint256 lastTokenIndex = tokenLen - 1;

    // find and deregister the token
    for (uint256 i; i < tokenLen; ) {
      if (traderToken[i] == _token) {
        // delete the token by replacing it with the last one and then pop it from there
        if (i != lastTokenIndex) {
          traderToken[i] = traderToken[lastTokenIndex];
        }
        traderToken.pop();
        break;
      }

      unchecked {
        i++;
      }
    }
  }

  function _validateRemoveTraderToken(address _trader, address _token) private view {
    if (traderBalances[_trader][_token] != 0) revert IVaultStorage_TraderBalanceRemaining();
  }

  function _validateAddTraderToken(address _trader, address _token) private view {
    address[] storage traderToken = traderTokens[_trader];

    for (uint256 i; i < traderToken.length; ) {
      if (traderToken[i] == _token) revert IVaultStorage_TraderTokenAlreadyExists();
      unchecked {
        i++;
      }
    }
  }
}
