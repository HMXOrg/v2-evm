// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IVaultStorage } from "./interfaces/IVaultStorage.sol";

/// @title VaultStorage
/// @notice storage contract to do accounting for token, and also hold physical tokens
contract VaultStorage is IVaultStorage {
  using SafeERC20 for IERC20;

  // EVENTs
  event LogSetTraderBalance(address indexed trader, address token, uint balance);

  mapping(address => uint256) public totalAmount; //token => tokenAmount
  mapping(address => uint256) public plpLiquidity; // token => PLPTokenAmount
  mapping(address => uint256) public fees; // fee in token unit

  uint256 public plpLiquidityDebtUSDE30; // USD dept accounting when tradingFee is not enough to repay to trader

  mapping(address => uint256) public fundingFee; // sum of realized funding fee when traders are settlement their fees
  mapping(address => uint256) public devFees;

  // liquidity provider address => token => amount
  mapping(address => mapping(address => uint256)) public liquidityProviderBalances;
  mapping(address => address[]) public liquidityProviderTokens;

  // trader address (with sub-account) => token => amount
  mapping(address => mapping(address => uint256)) public traderBalances;
  // mapping(address => address[]) public traderTokens;
  mapping(address => address[]) public traderTokens;

  // @todo - modifier?
  function addFee(address _token, uint256 _amount) public {
    fees[_token] += _amount;
  }

  function addDevFee(address _token, uint256 _amount) public {
    devFees[_token] += _amount;
  }

  function addFundingFee(address _token, uint256 _amount) public {
    fundingFee[_token] += _amount;
  }

  function removeFundingFee(address _token, uint256 _amount) public {
    fundingFee[_token] -= _amount;
  }

  function addPlpLiquidityDebtUSDE30(uint256 _value) public {
    plpLiquidityDebtUSDE30 += _value;
  }

  function removePlpLiquidityDebtUSDE30(uint256 _value) public {
    plpLiquidityDebtUSDE30 -= _value;
  }

  // @todo - modifier?
  function addPLPLiquidity(address _token, uint256 _amount) public {
    plpLiquidity[_token] += _amount;
  }

  /**
   * ERC20 interaction functions
   */
  function pullToken(address _token) external returns (uint256) {
    uint256 prevBalance = totalAmount[_token];
    uint256 nextBalance = IERC20(_token).balanceOf(address(this));

    totalAmount[_token] = nextBalance;

    return nextBalance - prevBalance;
  }

  function pushToken(address _token, address _to, uint256 _amount) external {
    IERC20(_token).safeTransfer(_to, _amount);
    totalAmount[_token] = IERC20(_token).balanceOf(address(this));
  }

  // @todo - modifier?
  function withdrawFee(address _token, uint256 _amount, address _receiver) external {
    if (_receiver == address(0)) revert IVaultStorage_ZeroAddress();
    // @todo only governance
    fees[_token] -= _amount;
    IERC20(_token).safeTransfer(_receiver, _amount);
  }

  // @todo - modifier?
  function removePLPLiquidity(address _token, uint256 _amount) public {
    plpLiquidity[_token] -= _amount;
  }

  /**
   * VALIDATION
   */

  function validateAddTraderToken(address _trader, address _token) public view {
    address[] storage traderToken = traderTokens[_trader];

    for (uint256 i; i < traderToken.length; ) {
      if (traderToken[i] == _token) revert IVaultStorage_TraderTokenAlreadyExists();
      unchecked {
        i++;
      }
    }
  }

  function validateRemoveTraderToken(address _trader, address _token) public view {
    if (traderBalances[_trader][_token] != 0) revert IVaultStorage_TraderBalanceRemaining();
  }

  /**
   * GETTER
   */

  function getTraderTokens(address _subAccount) external view returns (address[] memory) {
    return traderTokens[_subAccount];
  }

  /**
   * SETTER
   */

  function setTraderBalance(address _trader, address _token, uint256 _balance) public {
    traderBalances[_trader][_token] = _balance;
    emit LogSetTraderBalance(_trader, _token, _balance);
  }

  function addTraderToken(address _trader, address _token) external {
    validateAddTraderToken(_trader, _token);
    traderTokens[_trader].push(_token);
  }

  function removeTraderToken(address _trader, address _token) external {
    validateRemoveTraderToken(_trader, _token);

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

  /**
   * CALCULATION
   */
  // @todo - add only whitelisted services
  function transferToken(address _subAccount, address _token, uint256 _amount) external {
    IERC20(_token).safeTransfer(_subAccount, _amount);
  }

  function pullPLPLiquidity(address _token) external view returns (uint256) {
    return IERC20(_token).balanceOf(address(this)) - plpLiquidity[_token];
  }

  /// @notice increase sub-account collateral
  /// @param _subAccount - sub account
  /// @param _token - collateral token to increase
  /// @param _amount - amount to increase
  function increaseTraderBalance(address _subAccount, address _token, uint256 _amount) external {
    traderBalances[_subAccount][_token] += _amount;
  }

  /// @notice decrease sub-account collateral
  /// @param _subAccount - sub account
  /// @param _token - collateral token to increase
  /// @param _amount - amount to increase
  function decreaseTraderBalance(address _subAccount, address _token, uint256 _amount) external {
    traderBalances[_subAccount][_token] -= _amount;
  }

  /// @notice Pays the PLP for providing liquidity with the specified token and amount.
  /// @param _trader The address of the trader paying the PLP.
  /// @param _token The address of the token being used to pay the PLP.
  /// @param _amount The amount of the token being used to pay the PLP.
  function payPlp(address _trader, address _token, uint256 _amount) external {
    // Increase the PLP's liquidity for the specified token
    plpLiquidity[_token] += _amount;
    // Decrease the trader's balance for the specified token
    traderBalances[_trader][_token] -= _amount;
  }

  /**
   * ACCOUNTING
   */

  /// @notice This function does accounting when collecting trading fee from trader's sub-account.
  /// @param subAccount The sub-account from which to collect the fee.
  /// @param underlyingToken The underlying token for which the fee is collected.
  /// @param tradingFeeAmount The amount of trading fee to be collected, after deducting dev fee.
  /// @param devFeeTokenAmount The amount of dev fee deducted from the trading fee.
  /// @param traderBalance The updated balance of the trader's underlying token.
  function collectMarginFee(
    address subAccount,
    address underlyingToken,
    uint256 tradingFeeAmount,
    uint256 devFeeTokenAmount,
    uint256 traderBalance
  ) external {
    // Deduct dev fee from the trading fee and add it to the dev fee pool.
    addDevFee(underlyingToken, devFeeTokenAmount);
    // Add the remaining trading fee to the protocol's fee pool.
    addFee(underlyingToken, tradingFeeAmount);
    // Update the trader's balance of the underlying token.
    setTraderBalance(subAccount, underlyingToken, traderBalance);
  }

  /// @notice This function adds funding fees collected from a sub-account to the PLP liquidity in the vault.
  /// @param subAccount The sub-account from which to collect the fee.
  /// @param underlyingToken The underlying token for which the fee is collected.
  /// @param collectFeeTokenAmount The amount of funding fee to be collected.
  /// @param traderBalance The updated balance of the trader's underlying token.
  function collectFundingFee(
    address subAccount,
    address underlyingToken,
    uint256 collectFeeTokenAmount,
    uint256 traderBalance
  ) external {
    // Add the remaining fee amount to the plp liquidity in the vault
    addFundingFee(underlyingToken, collectFeeTokenAmount);
    // Update the sub-account balance for the plp underlying token in the vault
    setTraderBalance(subAccount, underlyingToken, traderBalance);
  }

  /// @notice This function repays funding fees to the sub-account from the PLP liquidity in the vault.
  /// @param subAccount The sub-account to which to repay the fee.
  /// @param underlyingToken The underlying token for which the fee is repaid.
  /// @param repayFeeTokenAmount The amount of funding fee to be repaid.
  /// @param traderBalance The updated balance of the trader's underlying token.
  function repayFundingFee(
    address subAccount,
    address underlyingToken,
    uint256 repayFeeTokenAmount,
    uint256 traderBalance
  ) external {
    // Remove fee amount to trading fee in the vault
    removeFundingFee(underlyingToken, repayFeeTokenAmount);
    // Update the sub-account balance for the plp underlying token in the vault
    setTraderBalance(subAccount, underlyingToken, traderBalance);
  }

  /// @notice This function borrows funding fees from the PLP liquidity in the vault and adds it to the sub-account's balance.
  /// @param subAccount The sub-account to which to add the borrowed fee.
  /// @param underlyingToken The underlying token for which the fee is borrowed.
  /// @param borrowFeeTokenAmount The amount of funding fee to be borrowed.
  /// @param borrowFeeTokenValue The value of the borrowed funding fee in USD.
  /// @param traderBalance The updated balance of the trader's underlying token.
  function borrowFundingFeeFromPLP(
    address subAccount,
    address underlyingToken,
    uint256 borrowFeeTokenAmount,
    uint256 borrowFeeTokenValue,
    uint256 traderBalance
  ) external {
    // Add debt value on PLP
    addPlpLiquidityDebtUSDE30(borrowFeeTokenValue);
    removePLPLiquidity(underlyingToken, borrowFeeTokenAmount);
    // Update the sub-account balance for the plp underlying token in the vault
    setTraderBalance(subAccount, underlyingToken, traderBalance);
  }

  /// @notice This function repays funding fees borrowed from the PLP liquidity in the vault.
  /// @param subAccount The sub-account from which to repay the borrowed fee.
  /// @param underlyingToken The underlying token for which the fee is repaid.
  /// @param repayFeeTokenAmount The amount of funding fee to be repaid.
  /// @param repayFeeTokenValue The value of the repaid funding fee in USD.
  /// @param traderBalance The updated balance of the trader's underlying token.
  function repayFundingFeeToPLP(
    address subAccount,
    address underlyingToken,
    uint256 repayFeeTokenAmount,
    uint256 repayFeeTokenValue,
    uint256 traderBalance
  ) external {
    removePlpLiquidityDebtUSDE30(repayFeeTokenValue); // Remove debt value on PLP as received
    addPLPLiquidity(underlyingToken, repayFeeTokenAmount); // Add token amounts that PLP received
    setTraderBalance(subAccount, underlyingToken, traderBalance); // Update the sub-account's token balance
  }
}
