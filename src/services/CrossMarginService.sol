// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//base
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "@hmx/base/Owned.sol";

// contracts
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";

// Interfaces
import { ICrossMarginService } from "./interfaces/ICrossMarginService.sol";

contract CrossMarginService is Owned, ReentrancyGuard, ICrossMarginService {
  /**
   * Events
   */
  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogDepositCollateral(address indexed primaryAccount, address indexed subAccount, address token, uint256 amount);
  event LogWithdrawCollateral(
    address indexed primaryAccount,
    address indexed subAccount,
    address token,
    uint256 amount,
    address receiver
  );
  event LogWithdrawFundingFeeSurplus(uint256 surplusValue);

  /**
   * Structs
   */
  struct WithdrawFundingFeeSurplusVars {
    int256 totalAccumFundingLong;
    int256 totalAccumFundingShort;
    uint256 fundingFeeBookValue;
    bytes32 tokenAssetId;
    uint8 tokenDecimal;
    uint256 tokenPrice;
    uint256 fundingFeeAmount;
    uint256 totalFundingFeeReserveValueE30;
    uint256 fundingFeeSurplusValue;
  }

  /**
   * States
   */
  address public configStorage;
  address public vaultStorage;
  address public calculator;
  address public perpStorage;

  constructor(address _configStorage, address _vaultStorage, address _perpStorage, address _calculator) {
    if (_configStorage == address(0) || _vaultStorage == address(0) || _calculator == address(0))
      revert ICrossMarginService_InvalidAddress();

    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
    calculator = _calculator;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
    VaultStorage(_vaultStorage).devFees(address(0));
    PerpStorage(_perpStorage).getGlobalState();
    Calculator(_calculator).oracle();
  }

  /**
   * Modifiers
   */
  // NOTE: Validate only whitelisted contract be able to call this function
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  // NOTE: Validate only accepted collateral token to be deposited
  modifier onlyAcceptedToken(address _token) {
    ConfigStorage(configStorage).validateAcceptedCollateral(_token);
    _;
  }

  /**
   * Core Functions
   */
  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to calculate new trader balance when they deposit token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccountId Trader's Sub-Account Id.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    // Get trader's sub-account address
    address _subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // Increase collateral token balance
    _vaultStorage.increaseTraderBalance(_subAccount, _token, _amount);

    // Update token balance
    uint256 deltaBalance = _vaultStorage.pullToken(_token);
    if (deltaBalance < _amount) revert ICrossMarginService_InvalidDepositBalance();

    emit LogDepositCollateral(_primaryAccount, _subAccount, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to calculate new trader balance when they withdrawing token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccountId Trader's Sub-Account Id.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  function withdrawCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    address _receiver
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    // Get trader's sub-account address
    address _subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // Get current collateral token balance of trader's account
    // and deduct with new token withdrawing amount
    uint256 _oldBalance = _vaultStorage.traderBalances(_subAccount, _token);
    if (_amount > _oldBalance) revert ICrossMarginService_InsufficientBalance();

    // Decrease collateral token balance
    _vaultStorage.decreaseTraderBalance(_subAccount, _token, _amount);

    // Calculate validation for if new Equity is below IMR or not
    int256 equity = Calculator(calculator).getEquity(_subAccount, 0, 0);
    if (equity < 0 || uint256(equity) < Calculator(calculator).getIMR(_subAccount))
      revert ICrossMarginService_WithdrawBalanceBelowIMR();

    // Transfer withdrawing token from VaultStorage to destination wallet
    _vaultStorage.pushToken(_token, _receiver, _amount);

    emit LogWithdrawCollateral(_primaryAccount, _subAccount, _token, _amount, _receiver);
  }

  /// @notice Check funding fee surplus and transfer to PLP
  /// @dev Check if value on funding fee reserve have exceed balance for paying to traders
  ///      - If yes means exceed value are the surplus for platform and can be booked to PLP
  function withdrawFundingFeeSurplus(address _stableToken) external nonReentrant onlyWhitelistedExecutor {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);
    OracleMiddleware _oracle = OracleMiddleware(_configStorage.oracle());

    WithdrawFundingFeeSurplusVars memory _vars;

    // Get funding Fee LONG & SHORT on each market to find positive values
    // positive value mean how much protocol book funding fee value that will be paid to trader
    // Loop through all markets to sum funding fee on LONG and SHORT sides
    for (uint256 i = 0; i < _configStorage.getMarketConfigsLength(); ) {
      PerpStorage.Market memory _market = _perpStorage.getMarketByIndex(i);

      if (_market.accumFundingLong < 0) _vars.fundingFeeBookValue += uint256(-_market.accumFundingLong);

      if (_market.accumFundingShort < 0) _vars.fundingFeeBookValue += uint256(-_market.accumFundingShort);

      unchecked {
        ++i;
      }
    }

    // Calculate value of current Funding fee reserve
    _vars.tokenAssetId = _configStorage.tokenAssetIds(_stableToken);
    _vars.tokenDecimal = _configStorage.getAssetTokenDecimal(_stableToken);
    (_vars.tokenPrice, ) = _oracle.getLatestPrice(_vars.tokenAssetId, false);
    _vars.fundingFeeAmount = _vaultStorage.fundingFeeReserve(_stableToken);
    _vars.totalFundingFeeReserveValueE30 = (_vars.fundingFeeAmount * _vars.tokenPrice) / (10 ** _vars.tokenDecimal);

    // If fundingFeeBookValue > totalFundingFeeReserveValueE30 means protocol has exceed balance of fee reserved for paying to traders
    // Funding fee surplus = totalFundingFeeReserveValueE30 - fundingFeeBookValue
    if (_vars.fundingFeeBookValue > _vars.totalFundingFeeReserveValueE30 || (_vars.totalFundingFeeReserveValueE30 == 0))
      revert ICrossMarginHandler_NoFundingFeeSurplus();

    _vars.fundingFeeSurplusValue = _vars.totalFundingFeeReserveValueE30 - _vars.fundingFeeBookValue;
    // Transfer surplus amount to PLP
    {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _configStorage,
        _oracle,
        _vars.fundingFeeAmount,
        _vars.fundingFeeSurplusValue,
        _stableToken
      );

      _vaultStorage.withdrawSurplusFromFundingFeeReserveToPLP(_stableToken, _repayAmount);
      _vars.fundingFeeSurplusValue -= _repayValue;
    }
    // If fee cannot be covered, revert.
    if (_vars.fundingFeeSurplusValue > 0) revert ICrossMarginHandler_FundingFeeSurplusCannotBeCovered();

    emit LogWithdrawFundingFeeSurplus(_vars.fundingFeeSurplusValue);
  }

  /**
   * Setters
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ICrossMarginService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    VaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external nonReentrant onlyOwner {
    if (_perpStorage == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
  }

  /// @notice Set new Calculator contract address.
  /// @param _calculator New Calculator contract address.
  function setCalculator(address _calculator) external nonReentrant onlyOwner {
    if (_calculator == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetCalculator(calculator, _calculator);
    calculator = _calculator;

    // Sanity check
    Calculator(_calculator).oracle();
  }

  /**
   * Private Functions
   */

  /// @notice Calculate subAccount address on trader.
  /// @dev This uses to create subAccount address combined between Primary account and SubAccount ID.
  /// @param _primary Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @return _subAccount Trader's sub account address used for trading.
  function _getSubAccount(address _primary, uint8 _subAccountId) private pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function _getRepayAmount(
    ConfigStorage _configStorage,
    OracleMiddleware _oracle,
    uint256 _reserveBalance,
    uint256 _feeSurplusValueE30,
    address _token
  ) private view returns (uint256 _repayAmount, uint256 _repayValueE30) {
    bytes32 tokenAssetId = _configStorage.tokenAssetIds(_token);
    (uint256 tokenPrice, ) = _oracle.getLatestPrice(tokenAssetId, false);

    uint8 tokenDecimal = _configStorage.getAssetTokenDecimal(_token);
    uint256 feeSurplusAmount = (_feeSurplusValueE30 * (10 ** tokenDecimal)) / tokenPrice;

    if (_reserveBalance > feeSurplusAmount) {
      // _reserveBalance can cover the rest of the surplus fee
      return (feeSurplusAmount, _feeSurplusValueE30);
    } else {
      // _reserveBalance cannot cover the rest of the surplus fee, just take the amount the fee reserve have
      uint256 _reserveBalanceValue = (_reserveBalance * tokenPrice) / (10 ** tokenDecimal);
      return (_reserveBalance, _reserveBalanceValue);
    }
  }
}
