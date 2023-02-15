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
  ) external {
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );

    // TODO: validate circuit break
    ICalculator _calculator = ICalculator(
      IConfigStorage(configStorage).calculator()
    );

    // TODO fix here
    uint256 _price = 1e30;

    // 2. Calculate PLP amount to mint
    IConfigStorage.PLPTokenConfig memory tokenConfig = IConfigStorage(
      configStorage
    ).getPLPTokenConfig(_token);

    // if input incorrect or config accepted is false
    if (!tokenConfig.accepted) {
      revert LiquidityService_InvalidToken();
    }

    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }

    // 2.1 tokenValue = amount * priceE30 / 1e30
    uint256 tokenValueUsd = (_amount * _price) / PRICE_PRECISION;

    uint256 tokenValueInDecimals = _calculator.convertTokenDecimals(
      ERC20(_token).decimals(),
      USD_DECIMALS,
      tokenValueUsd
    );

    if (tokenValueInDecimals == 0) {
      revert LiquidityService_InsufficientLiquidityMint();
    }

    uint256 _feeRate = _calculator.getAddLiquidityFeeRate(
      _token,
      tokenValueUsd, //e18
      IConfigStorage(configStorage),
      IVaultStorage(vaultStorage)
    );

    uint256 amountAfterFee = _collectFee(
      _token,
      _price,
      _amount,
      _feeRate,
      _lpProvider
    );

    // 4. Check slippage: revert on error
    if (amountAfterFee < _minAmount)
      revert LiquidityService_InsufficientLiquidityMint();

    // TODO validate maxWeightDiff

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
    uint256 mintAmount = _calculator.getMintAmount(
      _calculator.getAUM(),
      ERC20(IConfigStorage(configStorage).plp()).totalSupply(),
      amountAfterFee
    );
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
}
