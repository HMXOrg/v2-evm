// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ILiquidityService } from "./interfaces/ILiquidityService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { PLPv2 } from "../contracts/PLPv2.sol";
import { IOracleMiddleware } from "../oracles/interfaces/IOracleMiddleware.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

/// @title LiquidityService
contract LiquidityService is ILiquidityService {
  using AddressUtils for address;

  IConfigStorage public configStorage;
  IVaultStorage public vaultStorage;
  IPerpStorage public perpStorage;

  uint256 internal constant PRICE_PRECISION = 10 ** 30;
  uint32 internal constant BPS = 1e4;
  uint8 internal constant USD_DECIMALS = 30;
  uint64 internal constant RATE_PRECISION = 1e18;

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

  constructor(IConfigStorage _configStorage, IVaultStorage _vaultStorage, IPerpStorage _perpStorage) {
    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
  }

  /* TODO 
  checklist
  -add whitelisted
  -emit event
  -realizedPNL
  */
  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256) {
    // 1. Check
    _validatePreAddRemoveLiquidity(_token, _amount);

    if (vaultStorage.pullToken(_token) != _amount) {
      revert LiquidityService_InvalidInputAmount();
    }

    ICalculator _calculator = ICalculator(configStorage.calculator());

    // 2. Query token min price to be used for joining pool
    (uint256 _price, ) = IOracleMiddleware(_calculator.oracle()).getLatestPrice(_token.toBytes32(), false);

    // 3. Calculate aum and load lpSupply before minting
    // TODO realize farm pnl to get pendingBorrowingFee
    uint256 _aum = _calculator.getAUM(true, 0, 0);

    uint256 _lpSupply = ERC20(configStorage.plp()).totalSupply();

    (uint256 _tokenValueUSDAfterFee, uint256 mintAmount) = _joinPool(
      _token,
      _amount,
      _price,
      _lpProvider,
      _minAmount,
      _aum,
      _lpSupply
    );

    // 4. Mint PLP to user
    PLPv2(configStorage.plp()).mint(_lpProvider, mintAmount);

    emit AddLiquidity(_lpProvider, _token, _amount, _aum, _lpSupply, _tokenValueUSDAfterFee, mintAmount);

    return mintAmount;
  }

  /* TODO 
  checklist
  -add whitelisted
  -emit event
  -realizedPNL
  */
  function removeLiquidity(
    address _lpProvider,
    address _tokenOut,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256) {
    // 1. Check
    _validatePreAddRemoveLiquidity(_tokenOut, _amount);

    ICalculator _calculator = ICalculator(configStorage.calculator());

    // TODO: should realized to get pendingBorrowingFee
    uint256 _aum = _calculator.getAUM(false, 0, 0);
    uint256 _lpSupply = ERC20(IConfigStorage(configStorage).plp()).totalSupply();

    // 2. Calculate LP value to remove
    uint256 _lpUsdValue = _lpSupply != 0 ? (_amount * _aum) / _lpSupply : 0;

    // 3. Perform exit pool
    uint256 _amountOut = _exitPool(_tokenOut, _lpUsdValue, _amount, _lpProvider, _minAmount);

    // 4. Settle tokens to user
    PLPv2(configStorage.plp()).burn(msg.sender, _amount);
    vaultStorage.pushToken(_tokenOut, msg.sender, _amountOut);

    emit RemoveLiquidity(_lpProvider, _tokenOut, _amount, _aum, _lpSupply, _lpUsdValue, _amountOut);

    return _amountOut;
  }

  function _joinPool(
    address _token,
    uint256 _amount,
    uint256 _price,
    address _lpProvider,
    uint256 _minAmount,
    uint256 _aum,
    uint256 _lpSupply
  ) internal returns (uint256 _tokenValueUSDAfterFee, uint256 _mintAmount) {
    ICalculator _calculator = ICalculator(configStorage.calculator());
    uint256 amountAfterFee = _collectFee(
      CollectFeeRequest(
        _token,
        _lpProvider,
        _price,
        _amount,
        _getFeeRate(_token, _amount, _price),
        LiquidityAction.ADD_LIQUIDITY
      )
    );

    // 4. Calculate mintAmount
    _tokenValueUSDAfterFee = _calculator.convertTokenDecimals(
      IConfigStorage(configStorage).getAssetTokenDecimal(_token),
      USD_DECIMALS,
      (amountAfterFee * _price) / PRICE_PRECISION
    );

    _mintAmount = _calculator.getMintAmount(_aum, _lpSupply, _tokenValueUSDAfterFee);

    // 5. Check slippage: revert on error
    if (_mintAmount < _minAmount) revert LiquidityService_InsufficientLiquidityMint();

    // 6. Update PLP accounting
    vaultStorage.addPLPLiquidity(_token, amountAfterFee);

    _validatePLPHealthCheck(_token);
  }

  function _exitPool(
    address _tokenOut,
    uint256 _lpUsdValue,
    uint256 _amount,
    address _lpProvider,
    uint256 _minAmount
  ) internal returns (uint256) {
    ICalculator _calculator = ICalculator(configStorage.calculator());

    (uint256 _maxPrice, ) = IOracleMiddleware(_calculator.oracle()).getLatestPrice(_tokenOut.toBytes32(), true);

    uint256 _amountOut = _calculator.convertTokenDecimals(
      30,
      IConfigStorage(configStorage).getAssetTokenDecimal(_tokenOut),
      (_lpUsdValue * PRICE_PRECISION) / _maxPrice
    );

    if (_amountOut == 0) revert LiquidityService_BadAmountOut();

    vaultStorage.removePLPLiquidity(_tokenOut, _amountOut);

    uint256 _feeRate = ICalculator(configStorage.calculator()).getRemoveLiquidityFeeRate(
      _tokenOut,
      _lpUsdValue,
      IConfigStorage(configStorage)
    );

    _amountOut = _collectFee(
      CollectFeeRequest(_tokenOut, _lpProvider, _maxPrice, _amount, _feeRate, LiquidityAction.REMOVE_LIQUIDITY)
    );

    if (_minAmount > _amountOut) {
      revert LiquidityService_Slippage();
    }

    return _amountOut;
  }

  function _getFeeRate(address _token, uint256 _amount, uint256 _price) internal returns (uint256) {
    uint256 tokenUSDValueE30 = ICalculator(configStorage.calculator()).convertTokenDecimals(
      ERC20(_token).decimals(),
      USD_DECIMALS,
      (_amount * _price) / PRICE_PRECISION // tokenValueInDecimal = amount * priceE30 / 1e30
    );

    if (tokenUSDValueE30 == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    uint256 _feeRate = ICalculator(configStorage.calculator()).getAddLiquidityFeeRate(
      _token,
      tokenUSDValueE30,
      IConfigStorage(configStorage)
    );

    return _feeRate;
  }

  // calculate fee and accounting fee
  function _collectFee(CollectFeeRequest memory _request) internal returns (uint256) {
    uint256 _fee = (_request._amount * _request._feeRate) / RATE_PRECISION;

    vaultStorage.addFee(_request._token, _fee);
    uint256 _decimals = IConfigStorage(configStorage).getAssetTokenDecimal(_request._token);

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
    if (vaultStorage.plpLiquidity(_token) < configStorage.getAssetPlpTokenConfigByToken(_token).bufferLiquidity) {
      revert LiquidityService_InsufficientLiquidityBuffer();
    }

    IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
    IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();
    ICalculator _calculator = ICalculator(configStorage.calculator());

    // Validate Max PLP Utilization
    // =====================================
    // reserveValue / PLPTVL > maxPLPUtilization
    // Transform to save precision:
    // reserveValue > maxPLPUtilization * PLPTVL
    uint256 plpTVL = _calculator.getPLPValueE30(false, 0, 0);
    if (_globalState.reserveValueE30 * BPS > _liquidityConfig.maxPLPUtilizationBPS * plpTVL) {
      revert LiquidityService_MaxPLPUtilizationExceeded();
    }

    // Validate PLP Reserved
    if (_globalState.reserveValueE30 > plpTVL) {
      revert LiquidityService_InsufficientPLPReserved();
    }
  }

  function _validatePreAddRemoveLiquidity(address _token, uint256 _amount) internal view {
    configStorage.validateServiceExecutor(address(this), msg.sender);

    if (!configStorage.getLiquidityConfig().enabled) {
      revert LiquidityService_CircuitBreaker();
    }

    if (!configStorage.getAssetPlpTokenConfigByToken(_token).accepted) {
      revert LiquidityService_InvalidToken();
    }

    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }
  }
}
