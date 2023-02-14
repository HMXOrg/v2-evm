// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ILiquidityService } from "./interfaces/ILiquidityService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { PLPv2 } from "../contracts/PLPv2.sol";

/// @title LiquidityService
contract LiquidityService is ILiquidityService {
  address configStorage;
  address vaultStorage;

  uint256 internal constant PRICE_PRECISION = 10 ** 30;
  uint256 internal constant USD_DECIMALS = 18;

  enum LiquidityDirection {
    ADD,
    REMOVE
  }

  constructor(address _configStorage, address _vaultStorage) {
    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
  }

  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external {
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );

    // TODO: validate circuit break
    // 1. Calculate and cache new PLP Price
    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    // TODO fix here
    uint256 price = 1 ether;

    // 2. Calculate PLP amount to mint
    // 2.1 cal tokenValue = amount* tokenPrice
    uint256 tokenValueUsd = (_amount * price) / PRICE_PRECISION;

    IConfigStorage.PLPTokenConfig memory tokenConfig = IConfigStorage(
      configStorage
    ).getPLPTokenConfig(_token);

    // if input incorrect or config accepted is false
    if (!tokenConfig.accepted) {
      revert LiquidityService_InvalidToken();
    }

    uint256 tokenValueInDecimals = _calculator.convertTokenDecimals(
      ERC20(_token).decimals(),
      USD_DECIMALS,
      tokenValueUsd
    );

    if (tokenValueInDecimals == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    // 3 collect deposit fee
    uint256 _tokenPriceUsd = 0;

    // Accouting protocol fee
    uint256 amountAfterFee = _collectFee(
      _token,
      _tokenPriceUsd,
      _amount,
      _getFeeAddLiquidityRate(_token, tokenValueInDecimals),
      _lpProvider
    );

    // 4. Check slippage: revert on error
    if (amountAfterFee < _minAmount) {
      revert LiquidityService_InsufficientLiquidityMint();
    }
    // 5. Call VaultStorage: Add Liquidity and Collect Deposit Fee

    // Increase token liquidity
    _incrementLPBalance(_lpProvider, _token, amountAfterFee);

    // Transfer Token from LiquidityHandler to VaultStorage
    ERC20(_token).transferFrom(
      msg.sender,
      address(vaultStorage),
      amountAfterFee
    );

    // 6. Mint PLP to user
    uint256 mintAmount = _calculator.getAUM() == 0
      ? amountAfterFee
      : (amountAfterFee *
        ERC20(IConfigStorage(configStorage).plp()).totalSupply()) /
        _calculator.getAUM();
    PLPv2(IConfigStorage(configStorage).plp()).mint(_lpProvider, mintAmount);
  }

  function _incrementLPBalance(
    address _lpProvider,
    address _token,
    uint256 _amount
  ) internal {
    uint oldBalance = IVaultStorage(vaultStorage).liquidityProviderBalances(
      _lpProvider,
      _token
    );
    uint newBalance = oldBalance + _amount;

    IVaultStorage(vaultStorage).setLiquidityProviderBalances(
      _lpProvider,
      _token,
      _amount
    );

    // register new token to a user
    if (oldBalance == 0 && newBalance != 0) {
      IVaultStorage(vaultStorage).setLiquidityProviderTokens(
        _lpProvider,
        _token
      );
    }
  }

  /*
  // TODO: move to service
  function decrementLPBalance(
    address liquidityProviderAddress,
    address token,
    uint256 amount
  ) external {
    uint oldBalance = liquidityProviderBalances[liquidityProviderAddress][
      token
    ];
    if (amount > oldBalance) revert("insufficient balance");

    uint newBalance = oldBalance - amount;
    liquidityProviderBalances[liquidityProviderAddress][token] = newBalance;

    // deregister token, if the use remove all of the token out
    if (oldBalance != 0 && newBalance == 0) {
      address[] storage liquidityProviderToken = liquidityProviderTokens[
        liquidityProviderAddress
      ];
      uint256 tokenLen = liquidityProviderToken.length;
      uint256 lastTokenIndex = tokenLen - 1;

      // find and deregister the token
      for (uint256 i; i < tokenLen; i++) {
        if (liquidityProviderToken[i] == token) {
          // delete the token by replacing it with the last one and then pop it from there
          if (i != lastTokenIndex) {
            liquidityProviderToken[i] = liquidityProviderToken[lastTokenIndex];
          }
          liquidityProviderToken.pop();
          break;
        }
      }
    }
  } */

  function _getFeeAddLiquidityRate(
    address _token,
    uint256 _tokenValue
  ) internal returns (uint256) {
    IConfigStorage.LiquidityConfig memory _liquidityConfig = IConfigStorage(
      configStorage
    ).getLiquidityConfig();
    if (!_liquidityConfig.dynamicFeeEnabled) {
      return _liquidityConfig.depositFeeRate;
    }
    //TODO feeLiquidity
    return (0);
    // return getFeeBps(token, value, _feeBps, _taxBps, direction);
  }

  function _collectFee(
    address _token,
    uint256 _tokenPriceUsd,
    uint256 _amount,
    uint256 _feeRate,
    address _account
  ) internal returns (uint256) {
    uint256 amountAfterFee = (_amount * (1e18 - _feeRate)) / _feeRate;
    uint256 fee = _amount - amountAfterFee;

    IVaultStorage(vaultStorage).addFee(
      _token,
      fee + IVaultStorage(vaultStorage).fees(_token)
    );

    return amountAfterFee;
    // TODO emit event seperately ???
    /*  if (action == LiquidityAction.SWAP) {
      emit CollectSwapFee(
        account,
        token,
        (fee * tokenPriceUsd) / 10 ** ERC20(token).decimals(),
        fee
      );
    } else if (action == LiquidityAction.ADD_LIQUIDITY) {
      emit CollectAddLiquidityFee(
        account,
        token,
        (fee * tokenPriceUsd) / 10 ** ERC20(token).decimals(),
        fee
      );
    } else if (action == LiquidityAction.REMOVE_LIQUIDITY) {
      emit CollectRemoveLiquidityFee(
        account,
        token,
        (fee * tokenPriceUsd) / 10 ** ERC20(token).decimals(),
        fee
      ); */
  }
  /*

  function getFeeBps(
    address _token,
    uint256 _value,
    uint256 _feeBps,
    uint256 _taxBps,
    LiquidityDirection direction
  ) internal view returns (uint256) {

   

    uint256 startValue = configStorage.[token];
    uint256 nextValue = startValue + value;
    if (direction == LiquidityDirection.REMOVE)
      nextValue = value > startValue ? 0 : startValue - value;

    uint256 targetValue = getTargetValue(token);
    if (targetValue == 0) return _feeBps;

    uint256 startTargetDiff = startValue > targetValue
      ? startValue - targetValue
      : targetValue - startValue;
    uint256 nextTargetDiff = nextValue > targetValue
      ? nextValue - targetValue
      : targetValue - nextValue;

    // nextValue moves closer to the targetValue -> positive case;
    // Should apply rebate.
    if (nextTargetDiff < startTargetDiff) {
      uint256 rebateBps = (_taxBps * startTargetDiff) / targetValue;
      return rebateBps > _feeBps ? 0 : _feeBps - rebateBps;
    }

    // If not then -> negative impact to the pool.
    // Should apply tax.
    uint256 midDiff = (startTargetDiff + nextTargetDiff) / 2;
    if (midDiff > targetValue) {
      midDiff = targetValue;
    }
    _taxBps = (_taxBps * midDiff) / targetValue;

    return _feeBps + _taxBps;
  }


  function getTargetValue(address token) public view returns (uint256) {
    // SLOAD
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();
    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigDs = LibPoolConfigV1.poolConfigV1DiamondStorage();

    uint256 cachedTotalUsdDebt = poolV1ds.totalUsdDebt;

    if (cachedTotalUsdDebt == 0) return 0;

    return
      (cachedTotalUsdDebt * poolConfigDs.tokenMetas[token].weight) /
      poolConfigDs.totalTokenWeight;
  } */
}
