// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IVaultStorage } from "./interfaces/IVaultStorage.sol";

/// @title VaultStorage
/// @notice storage contract to do accounting for token, and also hold physical tokens
abstract contract VaultStorage is IVaultStorage {
  // liquidity provider address => token => amount
  mapping(address => mapping(address => uint256))
    public liquidityProviderBalances;
  mapping(address => address[]) public liquidityProviderTokens;

  // trader address (with sub-account) => token => amount
  mapping(address => mapping(address => uint256)) public traderBalances;
  mapping(address => address[]) public traderTokens;

  // TODO: move to service
  function incrementLPBalance(
    address liquidityProviderAddress,
    address token,
    uint256 amount
  ) external {
    uint oldBalance = liquidityProviderBalances[liquidityProviderAddress][
      token
    ];
    uint newBalance = oldBalance + amount;

    liquidityProviderBalances[liquidityProviderAddress][token] = newBalance;

    // register new token to a user
    if (oldBalance == 0 && newBalance != 0) {
      address[] storage liquidityProviderToken = liquidityProviderTokens[
        liquidityProviderAddress
      ];
      liquidityProviderToken.push(token);
    }
  }

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
  }
}
