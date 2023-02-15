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
  uint256 internal constant USD_DECIMALS = 18;

  event AddLiquidity(
    address account,
    address token,
    uint256 amount,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 mintAmount
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

  //TODO add whitelisted (because to trust _amount from handler)
  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256) {
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );

    if (!IConfigStorage(configStorage).getLiquidityConfig().enabled) {
      revert LiquidityService_CircuitBreaker();
    }

    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    (uint256 _price, ) = IOracleMiddleware(_calculator.oracle()).getLatestPrice(
      _token.toBytes32(),
      false,
      IConfigStorage(configStorage)
        .getMarketConfigByToken(_token)
        .priceConfidentThreshold
    );

    //TODO price stale

    // 2. Calculate PLP amount to mint
    // if input incorrect or config accepted is false
    if (!IConfigStorage(configStorage).getPLPTokenConfig(_token).accepted) {
      revert LiquidityService_InvalidToken();
    }

    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }

    uint256 _feeRate = _getFeeRate(_token, _amount, _price);

    //3 get aum and lpSupply before deduction fee
    uint256 _aum = _calculator.getAUM(false);
    uint256 _lpSupply = ERC20(IConfigStorage(configStorage).plp())
      .totalSupply();

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

    //5 Calculate mintAmount
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

    //5.1 accounting PLP
    _incrementLPBalance(_token, amountAfterFee, tokenValueUSDAfterFee);

    //5.2 Transfer Token from LiquidityHandler to VaultStorage
    ERC20(_token).transferFrom(
      msg.sender,
      address(vaultStorage),
      amountAfterFee
    );

    // 6. Mint PLP to user
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

  function _getFeeRate(
    address _token,
    uint256 _amount,
    uint256 _price
  ) internal returns (uint256) {
    uint256 tokenUSDValue = ICalculator(
      IConfigStorage(configStorage).calculator()
    ).convertTokenDecimals(
        ERC20(_token).decimals(),
        USD_DECIMALS,
        (_amount * _price) / PRICE_PRECISION // tokenValueInDecimal = amount * priceE30 / 1e30
      );

    if (tokenUSDValue == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    uint256 _feeRate = ICalculator(IConfigStorage(configStorage).calculator())
      .getAddLiquidityFeeRate(
        _token,
        tokenUSDValue, //e18
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

  function _incrementLPBalance(
    address _token,
    uint256 _amountAfterFee,
    uint256 _plpValueUSD
  ) internal {
    // increase plpLiquidity
    IVaultStorage(_token).addPLPLiquidity(_token, _amountAfterFee);

    // increase plpLiquidityUSD
    IVaultStorage(_token).addPLPLiquidityUSD(_token, _plpValueUSD);

    // increase total
    IVaultStorage(_token).addPLPTotalLiquidityUSD(_plpValueUSD);
  }
}
