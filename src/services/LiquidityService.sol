// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contracts
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";

// interfaces
import { ILiquidityService } from "./interfaces/ILiquidityService.sol";

contract LiquidityService is ReentrancyGuard, ILiquidityService {
  address public configStorage;
  address public vaultStorage;
  address public perpStorage;

  uint256 internal constant PRICE_PRECISION = 10 ** 30;
  uint32 internal constant BPS = 1e4;
  uint8 internal constant USD_DECIMALS = 30;

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

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
  }

  /**
   * MODIFIER
   */

  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  modifier onlyAcceptedToken(address _token) {
    ConfigStorage(configStorage).validateAcceptedLiquidityToken(_token);
    _;
  }

  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) returns (uint256) {
    // 1. _validate
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    validatePreAddRemoveLiquidity(_amount);

    if (VaultStorage(vaultStorage).pullToken(_token) != _amount) {
      revert LiquidityService_InvalidInputAmount();
    }

    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    // 2. getMinPrice for using to join Pool
    (uint256 _price, ) = OracleMiddleware(_calculator.oracle()).getLatestPrice(
      ConfigStorage(configStorage).tokenAssetIds(_token),
      false
    );

    // 3. get aum and lpSupply before deduction fee
    uint256 _aumE30 = _calculator.getAUME30(true);
    uint256 _lpSupply = ERC20(ConfigStorage(configStorage).plp()).totalSupply();

    (uint256 _tokenValueUSDAfterFee, uint256 mintAmount) = _joinPool(
      _token,
      _amount,
      _price,
      _lpProvider,
      _minAmount,
      _aumE30,
      _lpSupply
    );

    //7 Transfer Token from LiquidityHandler to VaultStorage and Mint PLP to user
    PLPv2(ConfigStorage(configStorage).plp()).mint(_lpProvider, mintAmount);

    emit AddLiquidity(_lpProvider, _token, _amount, _aumE30, _lpSupply, _tokenValueUSDAfterFee, mintAmount);
    return mintAmount;
  }

  function removeLiquidity(
    address _lpProvider,
    address _tokenOut,
    uint256 _amount,
    uint256 _minAmount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_tokenOut) returns (uint256) {
    // 1. _validate
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    validatePreAddRemoveLiquidity(_amount);

    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    uint256 _aum = _calculator.getAUME30(false);
    uint256 _lpSupply = ERC20(ConfigStorage(configStorage).plp()).totalSupply();

    // lp value to remove
    uint256 _lpUsdValueE30 = _lpSupply != 0 ? (_amount * _aum) / _lpSupply : 0;
    uint256 _amountOut = _exitPool(_tokenOut, _lpUsdValueE30, _lpProvider, _minAmount);

    // handler receive PLP of user then burn it from handler
    PLPv2(ConfigStorage(configStorage).plp()).burn(msg.sender, _amount);
    VaultStorage(vaultStorage).pushToken(_tokenOut, msg.sender, _amountOut);

    _validatePLPHealthCheck(_tokenOut);

    emit RemoveLiquidity(_lpProvider, _tokenOut, _amount, _aum, _lpSupply, _lpUsdValueE30, _amountOut);

    return _amountOut;
  }

  function _joinPool(
    address _token,
    uint256 _amount,
    uint256 _price,
    address _lpProvider,
    uint256 _minAmount,
    uint256 _aumE30,
    uint256 _lpSupply
  ) internal returns (uint256 _tokenValueUSDAfterFee, uint256 mintAmount) {
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());
    uint256 amountAfterFee = _collectFee(
      CollectFeeRequest(
        _token,
        _lpProvider,
        _price,
        _amount,
        _getAddLiquidityFeeBPS(_token, _amount, _price),
        LiquidityAction.ADD_LIQUIDITY
      )
    );

    // 4. Calculate mintAmount
    _tokenValueUSDAfterFee = _calculator.convertTokenDecimals(
      ConfigStorage(configStorage).getAssetTokenDecimal(_token),
      USD_DECIMALS,
      (amountAfterFee * _price) / PRICE_PRECISION
    );

    mintAmount = _calculator.getMintAmount(_aumE30, _lpSupply, _tokenValueUSDAfterFee);

    // 5. Check slippage: revert on error
    if (mintAmount < _minAmount) revert LiquidityService_InsufficientLiquidityMint();

    //6 accounting PLP (plpLiquidityUSD,total, plpLiquidity)
    VaultStorage(vaultStorage).addPLPLiquidity(_token, amountAfterFee);

    _validatePLPHealthCheck(_token);

    return (_tokenValueUSDAfterFee, mintAmount);
  }

  function _exitPool(
    address _tokenOut,
    uint256 _lpUsdValueE30,
    address _lpProvider,
    uint256 _minAmount
  ) internal returns (uint256) {
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());
    (uint256 _maxPrice, ) = OracleMiddleware(_calculator.oracle()).getLatestPrice(
      ConfigStorage(configStorage).tokenAssetIds(_tokenOut),
      false
    );

    uint256 _amountOut = _calculator.convertTokenDecimals(
      30,
      ConfigStorage(configStorage).getAssetTokenDecimal(_tokenOut),
      (_lpUsdValueE30 * PRICE_PRECISION) / _maxPrice
    );

    if (_amountOut == 0) revert LiquidityService_BadAmountOut();

    uint32 _feeBps = Calculator(ConfigStorage(configStorage).calculator()).getRemoveLiquidityFeeBPS(
      _tokenOut,
      _lpUsdValueE30,
      ConfigStorage(configStorage)
    );

    VaultStorage(vaultStorage).removePLPLiquidity(_tokenOut, _amountOut);

    _amountOut = _collectFee(
      CollectFeeRequest(_tokenOut, _lpProvider, _maxPrice, _amountOut, _feeBps, LiquidityAction.REMOVE_LIQUIDITY)
    );

    if (_minAmount > _amountOut) {
      revert LiquidityService_Slippage();
    }

    return _amountOut;
  }

  function _getAddLiquidityFeeBPS(address _token, uint256 _amount, uint256 _price) internal view returns (uint32) {
    uint256 tokenUSDValueE30 = Calculator(ConfigStorage(configStorage).calculator()).convertTokenDecimals(
      ConfigStorage(configStorage).getAssetTokenDecimal(_token),
      USD_DECIMALS,
      (_amount * _price) / PRICE_PRECISION // tokenValueInDecimal = amount * priceE30 / 1e30
    );

    if (tokenUSDValueE30 == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    uint32 _feeBps = Calculator(ConfigStorage(configStorage).calculator()).getAddLiquidityFeeBPS(
      _token,
      tokenUSDValueE30,
      ConfigStorage(configStorage)
    );

    return _feeBps;
  }

  // calculate fee and accounting fee
  function _collectFee(CollectFeeRequest memory _request) internal returns (uint256) {
    uint256 _fee = _request._amount - ((_request._amount * (BPS - _request._feeBPS)) / BPS);

    VaultStorage(vaultStorage).addFee(_request._token, _fee);
    uint256 _decimals = ConfigStorage(configStorage).getAssetTokenDecimal(_request._token);

    if (_request._action == LiquidityAction.SWAP) {
      emit CollectSwapFee(_request._account, _request._token, (_fee * _request._tokenPriceUsd) / 10 ** _decimals, _fee);
    } else if (_request._action == LiquidityAction.ADD_LIQUIDITY) {
      emit CollectAddLiquidityFee(
        _request._account,
        _request._token,
        (_fee * _request._tokenPriceUsd) / 10 ** _decimals,
        _fee
      );
    } else if (_request._action == LiquidityAction.REMOVE_LIQUIDITY) {
      emit CollectRemoveLiquidityFee(
        _request._account,
        _request._token,
        (_fee * _request._tokenPriceUsd) / 10 ** _decimals,
        _fee
      );
    }
    return _request._amount - _fee;
  }

  function _validatePLPHealthCheck(address _token) internal view {
    // liquidityLeft < bufferLiquidity
    if (
      VaultStorage(vaultStorage).plpLiquidity(_token) <
      ConfigStorage(configStorage).getAssetPlpTokenConfigByToken(_token).bufferLiquidity
    ) {
      revert LiquidityService_InsufficientLiquidityBuffer();
    }

    ConfigStorage.LiquidityConfig memory _liquidityConfig = ConfigStorage(configStorage).getLiquidityConfig();
    PerpStorage.GlobalState memory _globalState = PerpStorage(perpStorage).getGlobalState();
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    // Validate Max PLP Utilization
    // =====================================
    // reserveValue / PLP TVL > maxPLPUtilization
    // Transform to save precision:
    // reserveValue > maxPLPUtilization * PLPTVL
    uint256 plpTVL = _calculator.getPLPValueE30(false);
    if (_globalState.reserveValueE30 * BPS > _liquidityConfig.maxPLPUtilizationBPS * plpTVL) {
      revert LiquidityService_MaxPLPUtilizationExceeded();
    }

    // Validate PLP Reserved
    if (_globalState.reserveValueE30 > plpTVL) {
      revert LiquidityService_InsufficientPLPReserved();
    }
  }

  /// @notice validatePreAddRemoveLiquidity used in Handler,Service
  /// @param _amount amountIn
  function validatePreAddRemoveLiquidity(uint256 _amount) public view {
    if (!ConfigStorage(configStorage).getLiquidityConfig().enabled) {
      revert LiquidityService_CircuitBreaker();
    }

    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }
  }
}
