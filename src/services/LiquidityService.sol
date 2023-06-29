// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.
//   _   _ __  ____  __
//  | | | |  \/  \ \/ /
//  | |_| | |\/| |\  /
//  |  _  | |  | |/  \
//  |_| |_|_|  |_/_/\_\
//

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

// contracts
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { HLP } from "@hmx/contracts/HLP.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";

// interfaces
import { ILiquidityService } from "./interfaces/ILiquidityService.sol";

/**
 * @title LiquidityService
 * @notice A contract that allows users to add and remove liquidity to/from the Perpetual Protocol.
 * This contract acts as a middleman between the liquidity providers and the Perpetual Protocol.
 * It ensures that the liquidity providers are charged the correct fees, and that the liquidity is
 * added/removed correctly to/from the protocol.
 *
 * The contract supports adding and removing liquidity for any token that is accepted by the protocol.
 * The contract also enforces various checks to ensure the health of the liquidity pool, such as
 * the maximum utilization rate and the minimum reserved value.
 */
contract LiquidityService is OwnableUpgradeable, ReentrancyGuardUpgradeable, ILiquidityService {
  /**
   * Events
   */
  event AddLiquidity(
    address account,
    address token,
    uint256 amount,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 mintAmount
  );
  event RemoveLiquidity(
    address account,
    address tokenOut,
    uint256 liquidity,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 amountOut
  );

  event CollectSwapFee(address user, address token, uint256 feeUsd, uint256 fee);
  event CollectAddLiquidityFee(address user, address token, uint256 feeUsd, uint256 fee);
  event CollectRemoveLiquidityFee(address user, address token, uint256 feeUsd, uint256 fee);

  /**
   * Structs
   */
  struct AddLiquidityVars {
    ConfigStorage configStorage;
    Calculator calculator;
    uint256 price;
    uint256 aumE30;
    uint256 lpSupply;
    uint256 tokenValueUSDAfterFee;
    uint256 mintAmount;
  }

  /**
   * States
   */
  address public configStorage;
  address public vaultStorage;
  address public perpStorage;

  uint256 internal constant PRICE_PRECISION = 10 ** 30;
  uint32 internal constant BPS = 1e4;
  uint8 internal constant USD_DECIMALS = 30;

  /// @notice Initializes the contract with the required storage contracts.
  /// @param _perpStorage The address of the PerpStorage contract.
  /// @param _vaultStorage The address of the VaultStorage contract.
  /// @param _configStorage The address of the ConfigStorage contract.
  function initialize(address _perpStorage, address _vaultStorage, address _configStorage) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).hlpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();
  }

  /**
   * Modifiers
   */

  /// @dev Modifier to allow only whitelisted executor to call a function.
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  /// @dev Modifier to allow only accepted liquidity token to be added or removed.
  /// @param _token The address of the liquidity token.
  modifier onlyAcceptedToken(address _token) {
    ConfigStorage(configStorage).validateAcceptedLiquidityToken(_token);
    _;
  }

  /**
   * Core Functions
   */

  /// @notice Adds liquidity to the liquidity pool using a specified token
  /// @param _lpProvider The address of the user providing the liquidity
  /// @param _token The address of the token being used to provide liquidity
  /// @param _amount The amount of the token being provided
  /// @param _minAmount The minimum amount of liquidity pool tokens (HLP) to be minted
  /// @return mintAmount The amount of liquidity pool tokens minted
  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) returns (uint256) {
    return _addLiquidity(_lpProvider, _token, _amount, _minAmount, _lpProvider);
  }

  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount,
    address _receiver
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) returns (uint256) {
    return _addLiquidity(_lpProvider, _token, _amount, _minAmount, _receiver);
  }

  function _addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount,
    address _receiver
  ) internal returns (uint256) {
    AddLiquidityVars memory _vars;

    // SLOAD
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = Calculator(_vars.configStorage.calculator());

    // 1. validate
    _validatePreAddRemoveLiquidity(_amount);

    if (VaultStorage(vaultStorage).pullToken(_token) < _amount) {
      revert LiquidityService_InvalidInputAmount();
    }

    // 2. get price for using to join Pool
    (_vars.price, ) = OracleMiddleware(_vars.calculator.oracle()).getLatestPrice(
      _vars.configStorage.tokenAssetIds(_token),
      false
    );

    // 3. get AUM and LpSupply before deduction fee
    _vars.aumE30 = _vars.calculator.getAUME30(true);
    _vars.lpSupply = ERC20Upgradeable(_vars.configStorage.hlp()).totalSupply();

    // 4. calculate hlp mint amount
    (_vars.tokenValueUSDAfterFee, _vars.mintAmount) = _joinPool(
      _token,
      _amount,
      _vars.price,
      _lpProvider,
      _minAmount,
      _vars.aumE30,
      _vars.lpSupply
    );

    // 5. mint HLP to lp provider
    HLP(_vars.configStorage.hlp()).mint(_receiver, _vars.mintAmount);

    if (HLP(_vars.configStorage.hlp()).totalSupply() < 1e18) revert LiquidityService_TinyShare();

    emit AddLiquidity(
      _lpProvider,
      _token,
      _amount,
      _vars.aumE30,
      _vars.lpSupply,
      _vars.tokenValueUSDAfterFee,
      _vars.mintAmount
    );
    return _vars.mintAmount;
  }

  /// @notice Allows a liquidity provider to remove liquidity from the pool
  /// @param _lpProvider The address of the liquidity provider
  /// @param _tokenOut The address of the token to be withdrawn
  /// @param _amount The amount of liquidity to be withdrawn
  /// @param _minAmount The minimum withdrawn token amount to be received
  /// @return The amount of tokens received by the liquidity provider
  function removeLiquidity(
    address _lpProvider,
    address _tokenOut,
    uint256 _amount,
    uint256 _minAmount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_tokenOut) returns (uint256) {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);

    // 1. pre-validate
    _validatePreAddRemoveLiquidity(_amount);

    // 2. get AUM and LpSupply
    uint256 _aumE30 = Calculator(_configStorage.calculator()).getAUME30(false);
    uint256 _lpSupply = ERC20Upgradeable(_configStorage.hlp()).totalSupply();

    // 3. calculate lp value to be removed
    uint256 _lpUsdValueE30 = _lpSupply != 0 ? (_amount * _aumE30) / _lpSupply : 0;
    uint256 _amountOutToken = _exitPool(_tokenOut, _lpUsdValueE30, _lpProvider, _minAmount);

    // 4. burn HLP from lp provider and transfer withdrawn token to LiquidityHandler
    HLP(_configStorage.hlp()).burn(msg.sender, _amount);
    VaultStorage(vaultStorage).pushToken(_tokenOut, msg.sender, _amountOutToken);

    // 5. post-validate
    _validateHLPHealthCheck(_tokenOut);

    if (HLP(_configStorage.hlp()).totalSupply() < 1e18) revert LiquidityService_TinyShare();

    emit RemoveLiquidity(_lpProvider, _tokenOut, _amount, _aumE30, _lpSupply, _lpUsdValueE30, _amountOutToken);

    return _amountOutToken;
  }

  /// @notice validatePreAddRemoveLiquidity used in Handler,Service
  /// @param _amount amountIn
  function validatePreAddRemoveLiquidity(uint256 _amount) external view {
    _validatePreAddRemoveLiquidity(_amount);
  }

  /**
   * Private Functions
   */

  /// @notice Adds liquidity to the pool by joining the pool.
  /// @param _token The address of the token to add to the pool.
  /// @param _amount The amount of _token to add to the pool.
  /// @param _price The latest price of the _token.
  /// @param _lpProvider The address of the user who is providing liquidity to the pool.
  /// @param _minMintAmount The minimum acceptable amount of liquidity to mint (HLP).
  /// @param _aumE30 The total Asset Under Management (AUM) of the pool in 10^30 units.
  /// @param _lpSupply The total supply of liquidity provider tokens.
  /// @return _tokenValueUSDAfterFee The value of the added _token in USD after deducting the liquidity provider fee.
  /// @return _mintAmount The amount of liquidity provider tokens (HLP tokens) minted after the liquidity addition.
  function _joinPool(
    address _token,
    uint256 _amount,
    uint256 _price,
    address _lpProvider,
    uint256 _minMintAmount,
    uint256 _aumE30,
    uint256 _lpSupply
  ) private returns (uint256 _tokenValueUSDAfterFee, uint256 _mintAmount) {
    // SLOAD
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    // 1. Calculate and collect fees
    uint32 _feeBps = _getAddLiquidityFeeBPS(_token, _amount, _price);
    uint256 amountAfterFee = _collectFee(_token, _lpProvider, _price, _amount, _feeBps, LiquidityAction.ADD_LIQUIDITY);

    // 2. Calculate mint amount
    _tokenValueUSDAfterFee = _convertTokenDecimals(
      ConfigStorage(configStorage).getAssetTokenDecimal(_token),
      USD_DECIMALS,
      (amountAfterFee * _price) / PRICE_PRECISION
    );

    _mintAmount = _calculator.getMintAmount(_aumE30, _lpSupply, _tokenValueUSDAfterFee);

    // 3. Check slippage: revert on error
    if (_mintAmount < _minMintAmount) revert LiquidityService_InsufficientLiquidityMint();

    // 4. Accounting LP
    VaultStorage(vaultStorage).addHLPLiquidity(_token, amountAfterFee);
    return (_tokenValueUSDAfterFee, _mintAmount);
  }

  /// @notice Exit pool by burning a specified amount of LP token, and receiving corresponding amount of `_tokenOut`.
  /// @param _tokenOut the address of token to receive after exit pool
  /// @param _lpUsdValueE30 the amount of liquidity pool token to burn, represented in USD value with 30 decimal places
  /// @param _lpProvider the address of the account providing the LP tokens to burn
  /// @param _minTokenAmount the minimum amount of `_tokenOut` that the user expects to receive after the swap, used to check the slippage
  /// @return _amountOut the actual amount of `_tokenOut` received after the swap
  function _exitPool(
    address _tokenOut,
    uint256 _lpUsdValueE30,
    address _lpProvider,
    uint256 _minTokenAmount
  ) private returns (uint256) {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    Calculator _calculator = Calculator(_configStorage.calculator());

    // 1. get price from oracle
    (uint256 _maxPrice, ) = OracleMiddleware(_calculator.oracle()).getLatestPrice(
      _configStorage.tokenAssetIds(_tokenOut),
      false
    );

    // 2. Calculate token amount out
    uint256 _amountOut = _convertTokenDecimals(
      USD_DECIMALS,
      _configStorage.getAssetTokenDecimal(_tokenOut),
      (_lpUsdValueE30 * PRICE_PRECISION) / _maxPrice
    );

    if (_amountOut == 0) revert LiquidityService_BadAmountOut();

    // 3. Calculate and collect fees
    uint32 _feeBps = _calculator.getRemoveLiquidityFeeBPS(_tokenOut, _lpUsdValueE30, _configStorage);
    VaultStorage(vaultStorage).removeHLPLiquidity(_tokenOut, _amountOut);
    _amountOut = _collectFee(_tokenOut, _lpProvider, _maxPrice, _amountOut, _feeBps, LiquidityAction.REMOVE_LIQUIDITY);

    if (_minTokenAmount > _amountOut) {
      revert LiquidityService_Slippage();
    }

    return _amountOut;
  }

  /// @notice Calculates the fee to charge for adding liquidity, in basis points.
  /// @dev The fee is calculated based on the token amount and the current price of the token.
  /// @param _token The address of the token being used for liquidity provision.
  /// @param _amount The amount of the token being used for liquidity provision.
  /// @param _price The current price of the token in USD.
  /// @return _feeBps The fee to charge for adding liquidity, in basis points.
  function _getAddLiquidityFeeBPS(
    address _token,
    uint256 _amount,
    uint256 _price
  ) private view returns (uint32 _feeBps) {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    Calculator _calculator = Calculator(_configStorage.calculator());

    uint256 tokenUSDValueE30 = _convertTokenDecimals(
      _configStorage.getAssetTokenDecimal(_token),
      USD_DECIMALS,
      (_amount * _price) / PRICE_PRECISION // tokenValueInDecimal = amount * priceE30 / 1e30
    );

    if (tokenUSDValueE30 == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    return _calculator.getAddLiquidityFeeBPS(_token, tokenUSDValueE30, _configStorage);
  }

  /// @dev Collects a fee from a user's account in a given token, and sends it to the fee recipient.
  /// @param _token The address of the token to collect the fee in.
  /// @param _account The address of the account to collect the fee from.
  /// @param _tokenPriceUsd The current price of the token in USD, represented as an E-30 decimal.
  /// @param _amount The amount of the token to collect as a fee.
  /// @param _feeBPS The fee percentage, represented as basis points.
  /// @param _action The liquidity action that triggered the fee collection.
  /// @return _amountAfterFee The amount of tokens actually collected as a fee.
  function _collectFee(
    address _token,
    address _account,
    uint256 _tokenPriceUsd,
    uint256 _amount,
    uint32 _feeBPS,
    LiquidityAction _action
  ) private returns (uint256 _amountAfterFee) {
    // SLOAD
    uint256 _decimals = ConfigStorage(configStorage).getAssetTokenDecimal(_token);

    // calculate and accounting fee collect amount
    uint256 _feeTokenAmount = (_amount * _feeBPS) / BPS;
    VaultStorage(vaultStorage).addFee(_token, _feeTokenAmount);

    if (_action == LiquidityAction.SWAP) {
      emit CollectSwapFee(_account, _token, (_feeTokenAmount * _tokenPriceUsd) / 10 ** _decimals, _feeTokenAmount);
    } else if (_action == LiquidityAction.ADD_LIQUIDITY) {
      emit CollectAddLiquidityFee(
        _account,
        _token,
        (_feeTokenAmount * _tokenPriceUsd) / 10 ** _decimals,
        _feeTokenAmount
      );
    } else if (_action == LiquidityAction.REMOVE_LIQUIDITY) {
      emit CollectRemoveLiquidityFee(
        _account,
        _token,
        (_feeTokenAmount * _tokenPriceUsd) / 10 ** _decimals,
        _feeTokenAmount
      );
    }

    return _amount - _feeTokenAmount;
  }

  function _validateHLPHealthCheck(address _token) private view {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);

    // liquidity left < buffer liquidity then revert
    if (
      VaultStorage(vaultStorage).hlpLiquidity(_token) <
      _configStorage.getAssetHlpTokenConfigByToken(_token).bufferLiquidity
    ) {
      revert LiquidityService_InsufficientLiquidityBuffer();
    }

    ConfigStorage.LiquidityConfig memory _liquidityConfig = _configStorage.getLiquidityConfig();
    PerpStorage.GlobalState memory _globalState = PerpStorage(perpStorage).getGlobalState();
    Calculator _calculator = Calculator(_configStorage.calculator());

    // Validate Max HLP Utilization
    // =====================================
    // reserveValue / HLP TVL > maxHLPUtilization
    // Transform to save precision:
    // reserveValue > maxHLPUtilization * HLP TVL
    uint256 hlpTVL = _calculator.getHLPValueE30(false);

    if (_globalState.reserveValueE30 * BPS > _liquidityConfig.maxHLPUtilizationBPS * hlpTVL) {
      revert LiquidityService_MaxHLPUtilizationExceeded();
    }

    // Validate HLP Reserved
    if (_globalState.reserveValueE30 > hlpTVL) {
      revert LiquidityService_InsufficientHLPReserved();
    }
  }

  function _validatePreAddRemoveLiquidity(uint256 _amount) private view {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    _configStorage.validateServiceExecutor(address(this), msg.sender);

    // Check if service is available for now
    if (!_configStorage.getLiquidityConfig().enabled) {
      revert LiquidityService_CircuitBreaker();
    }

    // Check bad amount
    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }
  }

  function _convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) internal pure returns (uint256) {
    return (amount * 10 ** toTokenDecimals) / 10 ** fromTokenDecimals;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
