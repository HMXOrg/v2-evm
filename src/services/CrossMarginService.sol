// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

//base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// contracts
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ConvertedGlpStrategy } from "@hmx/strategies/ConvertedGlpStrategy.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";

// Interfaces
import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";
import { ISwitchCollateralRouter } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralRouter.sol";

/**
 * @title CrossMarginService
 * @dev A cross-margin trading service that allows traders to deposit and withdraw collateral tokens.
 */
contract CrossMarginService is OwnableUpgradeable, ReentrancyGuardUpgradeable, ICrossMarginService {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;
  using SafeERC20Upgradeable for ERC20Upgradeable;

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
  event LogTransferCollateral(
    address indexed fromPrimaryAccount,
    uint8 fromSubAccountId,
    address indexed toPrimaryAccount,
    uint8 toSubAccountId,
    address token,
    uint256 amount
  );
  event LogWithdrawFundingFeeSurplus(uint256 surplusValue);
  event LogConvertSGlpCollateral(
    address primaryAccount,
    uint256 subAccountId,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut
  );
  event LogSetTradeHelper(address indexed oldTradeHelper, address newTradeHelper);

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
  /// @notice DEPRECATED.
  address public convertedSglpStrategy;
  address public tradeHelper;

  /// @dev Initializes the CrossMarginService contract.
  /// @param _configStorage The address of the ConfigStorage contract.
  /// @param _vaultStorage The address of the VaultStorage contract.
  /// @param _perpStorage The address of the PerpStorage contract.
  /// @param _calculator The address of the Calculator contract.
  /// @param _convertedSglpStrategy The address of the ConvertedGlpStrategy contract for converting GLP collateral to other tokens.
  function initialize(
    address _configStorage,
    address _vaultStorage,
    address _perpStorage,
    address _calculator,
    address _convertedSglpStrategy
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    if (
      _configStorage == address(0) ||
      _vaultStorage == address(0) ||
      _calculator == address(0) ||
      _convertedSglpStrategy == address(0)
    ) revert ICrossMarginService_InvalidAddress();

    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
    calculator = _calculator;

    convertedSglpStrategy = _convertedSglpStrategy;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
    VaultStorage(_vaultStorage).devFees(address(0));
    PerpStorage(_perpStorage).getGlobalState();
    Calculator(_calculator).oracle();
    ConvertedGlpStrategy(convertedSglpStrategy).sglp();
  }

  /**
   * Modifiers
   */

  /// @dev Modifier to allow only whitelisted executor to call a function.
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  /// @dev Modifier to allow only accepted collateral token to be deposited or withdrawn.
  /// @param _token The address of the collateral token.
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
    // SLOAD
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    // Get trader's sub-account address
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);

    // Increase collateral token balance
    _vaultStorage.increaseTraderBalance(_subAccount, _token, _amount);

    // Update token balance
    uint256 deltaBalance = _vaultStorage.pullToken(_token);
    if (deltaBalance != _amount) revert ICrossMarginService_InvalidDepositBalance();

    emit LogDepositCollateral(_primaryAccount, _subAccount, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to calculate new trader balance when they withdrawing token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccountId Trader's Sub-Account Id.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  /// @param _receiver The receiver address of the collateral
  function withdrawCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    address _receiver
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    // SLOAD
    Calculator _calculator = Calculator(calculator);

    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    // Get trader's sub-account address
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);

    // Get current collateral token balance of trader's account
    // and deduct with new token withdrawing amount
    uint256 _oldBalance = _vaultStorage.traderBalances(_subAccount, _token);
    if (_amount > _oldBalance) revert ICrossMarginService_InsufficientBalance();

    // Decrease collateral token balance
    _vaultStorage.decreaseTraderBalance(_subAccount, _token, _amount);

    // Calculate validation for if new Equity is below IMR or not
    int256 equity = _calculator.getEquity(_subAccount, 0, 0);
    if (equity < 0 || uint256(equity) < _calculator.getIMR(_subAccount))
      revert ICrossMarginService_WithdrawBalanceBelowIMR();

    // Transfer withdrawing token from VaultStorage to destination wallet
    _vaultStorage.pushToken(_token, _receiver, _amount);

    emit LogWithdrawCollateral(_primaryAccount, _subAccount, _token, _amount, _receiver);
  }

  /// @notice Calculate new trader balance after transfer collateral token.
  /// @param _params The parameters to transfer collateral.
  function transferCollateral(
    TransferCollateralParams calldata _params
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_params.token) {
    (
      address _fromPrimaryAccount,
      uint8 _fromSubAccountId,
      address _toPrimaryAccount,
      uint8 _toSubAccountId,
      address _token,
      uint256 _amount
    ) = (
        _params.fromPrimaryAccount,
        _params.fromSubAccountId,
        _params.toPrimaryAccount,
        _params.toSubAccountId,
        _params.token,
        _params.amount
      );
    // SLOAD
    Calculator _calculator = Calculator(calculator);

    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    // Get trader's sub-account address to withdraw from
    address _fromSubAccount = HMXLib.getSubAccount(_fromPrimaryAccount, _fromSubAccountId);
    // Get trader's sub-account address to deposit to
    address _toSubAccount = HMXLib.getSubAccount(_toPrimaryAccount, _toSubAccountId);

    // Get current collateral token balance of trader's subaccount
    // and deduct with new token withdrawing amount
    uint256 _oldBalance = _vaultStorage.traderBalances(_fromSubAccount, _token);
    if (_amount > _oldBalance) revert ICrossMarginService_InsufficientBalance();

    // Decrease collateral token balance of current subaccount
    _vaultStorage.decreaseTraderBalance(_fromSubAccount, _token, _amount);

    // Calculate validation for if new Equity is below IMR or not
    int256 equity = _calculator.getEquity(_fromSubAccount, 0, 0);
    if (equity < 0 || uint256(equity) < _calculator.getIMR(_fromSubAccount))
      revert ICrossMarginService_WithdrawBalanceBelowIMR();

    // Increase collateral token balance on target subaccount
    _vaultStorage.increaseTraderBalance(_toSubAccount, _token, _amount);

    emit LogTransferCollateral(
      _fromPrimaryAccount,
      _fromSubAccountId,
      _toPrimaryAccount,
      _toSubAccountId,
      _token,
      _amount
    );
  }

  /// @notice Check funding fee surplus and transfer to HLP
  /// @dev Check if value on funding fee reserve have exceed balance for paying to traders
  ///      - If yes means exceed value are the surplus for platform and can be booked to HLP
  function withdrawFundingFeeSurplus(address _stableToken) external nonReentrant onlyWhitelistedExecutor {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);
    OracleMiddleware _oracle = OracleMiddleware(_configStorage.oracle());

    WithdrawFundingFeeSurplusVars memory _vars;

    // This loop we go through `accumFundingLong` and `accumFundingShort` of each market
    // `accumFundingLong` and `accumFundingShort` are the unsettled funding fee of the market
    // we will use `fundingFeeBookValue` to sum up the current funding fee debt of every market
    // after we know all the current funding fee debt, we will compare it with `fundingFeeReserve`
    // to find out how much funding fee surplus there is in the platform.
    // (`fundingFeeReserve` keeps track of funding fee paid by traders)
    uint256 len = _configStorage.getMarketConfigsLength();
    for (uint256 i = 0; i < len; ) {
      PerpStorage.Market memory _market = _perpStorage.getMarketByIndex(i);

      // Update funding rate of the market to the latest value
      if (tradeHelper != address(0)) TradeHelper(tradeHelper).updateFundingRate(i);

      if (_market.accumFundingLong < 0) {
        // Only sum up the negative funding fee,
        // (negative funding fee means trader will receive funding fee)
        // we only care about negative funding fee here because
        // we would like to know how much the protocol owed the traders,
        // so that we will not withdraw too much funding fee surplus to the point that we can't pay the traders
        _vars.fundingFeeBookValue += uint256(-_market.accumFundingLong);
      }

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

    // If fundingFeeBookValue > totalFundingFeeReserveValueE30 means protocol has funds in `fundingFeeReserve` more than what the protocol owed the traders
    // so, the protocol is currently with funding fee surplus
    // funding fee surplus = totalFundingFeeReserveValueE30 - fundingFeeBookValue
    if (_vars.fundingFeeBookValue > _vars.totalFundingFeeReserveValueE30 || (_vars.totalFundingFeeReserveValueE30 == 0))
      revert ICrossMarginHandler_NoFundingFeeSurplus();

    _vars.fundingFeeSurplusValue = _vars.totalFundingFeeReserveValueE30 - _vars.fundingFeeBookValue;
    // Transfer surplus amount to HLP
    {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _configStorage,
        _oracle,
        _vars.fundingFeeAmount,
        _vars.fundingFeeSurplusValue,
        _stableToken
      );

      _vaultStorage.withdrawSurplusFromFundingFeeReserveToHLP(_stableToken, _repayAmount);
      _vars.fundingFeeSurplusValue -= _repayValue;
    }

    emit LogWithdrawFundingFeeSurplus(_vars.fundingFeeSurplusValue);
  }

  /// @notice Switch from one collateral token to another.
  /// @param _params The parameters for the switch.
  function switchCollateral(
    SwitchCollateralParams calldata _params
  ) external nonReentrant onlyWhitelistedExecutor returns (uint256 _toAmount) {
    // Checks
    // Check if path is valid
    if (_params.path.length < 2) revert ICrossMarginService_InvalidPath();
    // Check if switch from one collateral token to another
    ConfigStorage(configStorage).validateAcceptedCollateral(_params.path[0]);
    ConfigStorage(configStorage).validateAcceptedCollateral(_params.path[_params.path.length - 1]);
    // Check if amount is valid.
    if (_params.amount == 0) revert ICrossMarginService_InvalidAmount();

    // Casting dependencies
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    Calculator _calculator = Calculator(calculator);
    ISwitchCollateralRouter _switchCollateralRouter = ISwitchCollateralRouter(_configStorage.switchCollateralRouter());
    (address _tokenIn, address _tokenOut) = (_params.path[0], _params.path[_params.path.length - 1]);

    // Get trader's sub-account address
    address _subAccount = HMXLib.getSubAccount(_params.primaryAccount, _params.subAccountId);

    // Decrease trader's balance right here to prevent cross-contract reentrancy attack
    // We will treat as this amount is flashed transfered to _switchCollateralRouter
    // and expect that after _switchCollateralRouter done its job, the account should still healthy.
    // Hence, if the account unhealthy by cross-contract reentrancy attack, it will be reverted at the end.
    _vaultStorage.decreaseTraderBalance(_subAccount, _tokenIn, _params.amount);
    // Push token to _switchCollateralRouter
    _vaultStorage.pushToken(_tokenIn, address(_switchCollateralRouter), _params.amount);

    // Run _switchCollateralRouter, it will send back _tokenOut to this contract
    _toAmount = _switchCollateralRouter.execute(uint256(_params.amount), _params.path);
    // Check slippage
    if (_toAmount < _params.minToAmount) revert ICrossMarginService_Slippage();

    // Send last token to VaultStorage and pull
    ERC20Upgradeable(_tokenOut).safeTransfer(address(_vaultStorage), _toAmount);
    uint256 _deltaBalance = _vaultStorage.pullToken(_tokenOut);
    if (_deltaBalance != _toAmount) revert ICrossMarginService_InvalidDepositBalance();
    // Increase trader's balance
    _vaultStorage.increaseTraderBalance(_subAccount, _tokenOut, _toAmount);

    // Calculate validation if new Equity is below IMR or not
    int256 equity = _calculator.getEquity(_subAccount, 0, 0);
    if (equity < 0 || uint256(equity) < _calculator.getIMR(_subAccount))
      revert ICrossMarginService_WithdrawBalanceBelowIMR();
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

  /// @notice Set new TradeHelper contract address.
  /// @param _tradeHelper New TradeHelper contract address.
  function setTradeHelper(address _tradeHelper) external nonReentrant onlyOwner {
    if (_tradeHelper == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetTradeHelper(tradeHelper, _tradeHelper);
    tradeHelper = _tradeHelper;

    // Sanity check
    TradeHelper(_tradeHelper).perpStorage();
  }

  /**
   * Private Functions
   */
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

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
