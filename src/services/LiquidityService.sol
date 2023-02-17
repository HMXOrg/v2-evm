// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ILiquidityService } from "./interfaces/ILiquidityService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { PLPv2 } from "../contracts/PLPv2.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

/// @title LiquidityService
contract LiquidityService is ILiquidityService {
  using AddressUtils for address;
  address configStorage;
  address vaultStorage;

  uint256 internal constant PRICE_PRECISION = 10 ** 30;
  uint256 internal constant USD_DECIMALS = 30;

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

  event CollectSwapFee(
    address user,
    address token,
    uint256 feeUsd,
    uint256 fee
  );
  event CollectAddLiquidityFee(
    address user,
    address token,
    uint256 feeUsd,
    uint256 fee
  );
  event CollectRemoveLiquidityFee(
    address user,
    address token,
    uint256 feeUsd,
    uint256 fee
  );

  constructor(address _configStorage, address _vaultStorage) {
    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
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
    // 1. _validate
    _validatePreAddRemoveLiquidity(_token, _amount);

    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    //TODO price stale
    (uint256 _price, ) = IOracleMiddleware(_calculator.oracle())
      .unsafeGetLatestPrice(
        _token.toBytes32(),
        false,
        IConfigStorage(configStorage)
          .getMarketConfigByToken(_token)
          .priceConfidentThreshold
      );

    // 2. Calculate PLP amount to mint
    // if input incorrect or config accepted is false

    // 3. get aum and lpSupply before deduction fee
    // TODO realize farm pnl to get pendingBorrowingFee
    uint256 _aum = _calculator.getAUM(true);
    uint256 _lpSupply = ERC20(IConfigStorage(configStorage).plp())
      .totalSupply();

    (uint256 tokenValueUSDAfterFee, uint256 mintAmount) = _joinPool(
      _token,
      _amount,
      _price,
      _lpProvider,
      _minAmount,
      _aum,
      _lpSupply
    );

    //7 Transfer Token from LiquidityHandler to VaultStorage and Mint PLP to user
    ERC20(_token).transferFrom(msg.sender, address(vaultStorage), _amount);
    PLPv2(IConfigStorage(configStorage).plp()).mint(_lpProvider, mintAmount);

    emit AddLiquidity(
      _lpProvider,
      _token,
      _amount,
      _aum,
      _lpSupply,
      tokenValueUSDAfterFee,
      mintAmount
    );

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
    // 1. _validate
    _validatePreAddRemoveLiquidity(
      _tokenOut,
      IVaultStorage(vaultStorage).plpLiquidity(_tokenOut)
    );

    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    //TODO should realized to get pendingBorrowingFee
    uint256 _aum = _calculator.getAUM(false);
    uint256 _lpSupply = ERC20(IConfigStorage(configStorage).plp())
      .totalSupply();

    uint256 _lpUsdValue = (_amount * _aum) / _lpSupply;

    uint256 _amountOut = _exitPool(
      _tokenOut,
      _lpUsdValue,
      _amount,
      _lpProvider,
      _minAmount
    );

    // handler receive PLP of user then burn it from handler
    PLPv2(IConfigStorage(configStorage).plp()).burn(msg.sender, _amount);
    ERC20(_tokenOut).transferFrom(msg.sender, _lpProvider, _amountOut);

    emit RemoveLiquidity(
      _lpProvider,
      _tokenOut,
      _amount,
      _aum,
      _lpSupply,
      _lpUsdValue,
      _amountOut
    );

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
  ) internal returns (uint256, uint256) {
    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    uint256 _feeRate = _getFeeRate(_token, _amount, _price);
    uint256 amountAfterFee = _collectFee(
      CollectFeeRequest(
        _token,
        _price,
        _amount,
        _feeRate,
        _lpProvider,
        LiquidityAction.ADD_LIQUIDITY
      )
    );

    // 4. Check slippage: revert on error
    if (amountAfterFee < _minAmount)
      revert LiquidityService_InsufficientLiquidityMint();

    // 5. Calculate mintAmount
    uint256 tokenValueUSDAfterFee = _calculator.convertTokenDecimals(
      ERC20(_token).decimals(),
      USD_DECIMALS,
      amountAfterFee
    );

    uint256 mintAmount = _calculator.getMintAmount(
      _aum,
      _lpSupply,
      tokenValueUSDAfterFee
    );

    //6 accounting PLP (plpLiquidityUSD,total, plpLiquidity)
    IVaultStorage(_token).addPLPLiquidity(_token, amountAfterFee);
    IVaultStorage(_token).addPLPLiquidityUSDE30(_token, tokenValueUSDAfterFee);
    IVaultStorage(_token).addPLPTotalLiquidityUSDE30(tokenValueUSDAfterFee);

    _validatePLPHealthCheck(_token);

    return (tokenValueUSDAfterFee, mintAmount);
  }

  function _exitPool(
    address _tokenOut,
    uint256 _lpUsdValue,
    uint256 _amount,
    address _lpProvider,
    uint256 _minAmount
  ) internal returns (uint256) {
    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    // 2. Check totalLq < lpValue ()
    if (IVaultStorage(_tokenOut).plpTotalLiquidityUSDE30() < _lpUsdValue) {
      IVaultStorage(_tokenOut).addPLPTotalLiquidityUSDE30(
        _lpUsdValue - IVaultStorage(_tokenOut).plpTotalLiquidityUSDE30()
      );
    }

    // TODO price stale
    (uint256 _maxPrice, ) = IOracleMiddleware(_calculator.oracle())
      .unsafeGetLatestPrice(
        _tokenOut.toBytes32(),
        true,
        IConfigStorage(configStorage)
          .getMarketConfigByToken(_tokenOut)
          .priceConfidentThreshold
      );

    uint256 _amountOut = _calculator.convertTokenDecimals(
      30,
      ERC20(_tokenOut).decimals(),
      (_lpUsdValue * PRICE_PRECISION) / _maxPrice
    );

    if (_amountOut == 0) revert LiquidityService_BadAmountOut();

    IVaultStorage(_tokenOut).removePLPLiquidity(_tokenOut, _amountOut);
    IVaultStorage(_tokenOut).removePLPLiquidityUSDE30(_tokenOut, _lpUsdValue);
    IVaultStorage(_tokenOut).removePLPTotalLiquidityUSDE30(_lpUsdValue);

    uint256 _feeRate = ICalculator(IConfigStorage(configStorage).calculator())
      .getRemoveLiquidityFeeRate(
        _tokenOut,
        _lpUsdValue,
        IConfigStorage(configStorage),
        IVaultStorage(vaultStorage)
      );

    _amountOut = _collectFee(
      CollectFeeRequest(
        _tokenOut,
        _maxPrice,
        _amount,
        _feeRate,
        _lpProvider,
        LiquidityAction.REMOVE_LIQUIDITY
      )
    );

    if (_minAmount > _amountOut) {
      revert LiquidityService_BadAmountOut();
    }

    return _amountOut;
  }

  function _getFeeRate(
    address _token,
    uint256 _amount,
    uint256 _price
  ) internal returns (uint256) {
    uint256 tokenUSDValueE30 = ICalculator(
      IConfigStorage(configStorage).calculator()
    ).convertTokenDecimals(
        ERC20(_token).decimals(),
        USD_DECIMALS,
        (_amount * _price) / PRICE_PRECISION // tokenValueInDecimal = amount * priceE30 / 1e30
      );

    if (tokenUSDValueE30 == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    uint256 _feeRate = ICalculator(IConfigStorage(configStorage).calculator())
      .getAddLiquidityFeeRate(
        _token,
        tokenUSDValueE30,
        IConfigStorage(configStorage),
        IVaultStorage(vaultStorage)
      );

    return _feeRate;
  }

  // calculate fee and accounting fee
  function _collectFee(
    CollectFeeRequest memory _request
  ) internal returns (uint256) {
    uint256 amountAfterFee = (_request._amount * (1e18 - _request._feeRate)) /
      _request._feeRate;
    uint256 fee = _request._amount - amountAfterFee;

    IVaultStorage(vaultStorage).addFee(
      _request._token,
      fee + IVaultStorage(vaultStorage).fees(_request._token)
    );

    if (_request._action == LiquidityAction.SWAP) {
      emit CollectSwapFee(
        _request._account,
        _request._token,
        (fee * _request._tokenPriceUsd) /
          10 ** ERC20(_request._token).decimals(),
        fee
      );
    } else if (_request._action == LiquidityAction.ADD_LIQUIDITY) {
      emit CollectAddLiquidityFee(
        _request._account,
        _request._token,
        (fee * _request._tokenPriceUsd) /
          10 ** ERC20(_request._token).decimals(),
        fee
      );
    } else if (_request._action == LiquidityAction.REMOVE_LIQUIDITY) {
      emit CollectRemoveLiquidityFee(
        _request._account,
        _request._token,
        (fee * _request._tokenPriceUsd) /
          10 ** ERC20(_request._token).decimals(),
        fee
      );
    }
    return amountAfterFee;
  }

  function _validatePLPHealthCheck(address _token) internal view {
    uint256 _liquidityLeft = IVaultStorage(vaultStorage).plpLiquidity(_token) -
      IVaultStorage(vaultStorage).plpReserved(_token);

    // liquidityLeft < bufferLiquidity
    if (
      _liquidityLeft <
      IConfigStorage(configStorage).getPlpTokenConfigs(_token).bufferLiquidity
    ) {
      revert LiquidityService_InsufficientLiquidityBuffer();
    }
  }

  function _validatePreAddRemoveLiquidity(
    address _token,
    uint256 _amount
  ) internal {
    // 1. _validate
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );

    if (!IConfigStorage(configStorage).getLiquidityConfig().enabled) {
      revert LiquidityService_CircuitBreaker();
    }

    if (!IConfigStorage(configStorage).getPLPTokenConfig(_token).accepted) {
      revert LiquidityService_InvalidToken();
    }

    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }
  }
}
