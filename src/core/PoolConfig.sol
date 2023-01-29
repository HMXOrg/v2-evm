// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {IteratableAddressList} from "../libraries/IteratableAddressList.sol";

contract PoolConfig is Owned {
  using IteratableAddressList for IteratableAddressList.List;

  error PoolConfig_BadLen();
  error PoolConfig_BadArgs();

  struct TokenConfig {
    bool isAccept;
    uint8 decimals;
    uint64 weight;
  }

  IteratableAddressList.List public underlyingTokens;
  mapping(address => TokenConfig) public underlyingTokenConfigs;
  uint256 public totalUnderlyingWeight;

  event AddOrUpdateTokenConfigs(
    address token, TokenConfig prevConfig, TokenConfig newConfig
  );
  event RemoveUnderlying(address token);

  /// @notice Add or update underlying.
  /// @dev This function only allows to add new token or update existing token,
  /// any atetempt to remove token will be reverted.
  /// @param tokens The token addresses to set.
  /// @param configs The token configs to set.
  function addOrUpdateUnderlying(
    address[] calldata tokens,
    TokenConfig[] calldata configs
  ) external onlyOwner {
    if (tokens.length != configs.length) {
      revert PoolConfig_BadLen();
    }

    for (uint256 i = 0; i < tokens.length;) {
      // Enforce that isAccept must be true to prevent
      // removing underlying token through this function.
      if (!configs[i].isAccept) revert PoolConfig_BadArgs();

      // If underlyingTokenConfigs.isAccept is previously false,
      // then it is a new token to be added.
      if (!underlyingTokenConfigs[tokens[i]].isAccept) {
        underlyingTokens.add(tokens[i]);
      }

      // Log
      emit AddOrUpdateTokenConfigs(
        tokens[i], underlyingTokenConfigs[tokens[i]], configs[i]
        );

      // Update totalUnderlyingWeight accordingly
      totalUnderlyingWeight = (
        totalUnderlyingWeight - underlyingTokenConfigs[tokens[i]].weight
      ) + configs[i].weight;
      underlyingTokenConfigs[tokens[i]] = configs[i];

      unchecked {
        ++i;
      }
    }
  }

  function removeUnderlying(address token) external onlyOwner {
    // Update totalTokenWeight
    totalUnderlyingWeight -= underlyingTokenConfigs[token].weight;

    // Delete token from underlyingTokens list
    underlyingTokens.remove(token, underlyingTokens.getPreviousOf(token));
    // Delete underlying token config
    delete underlyingTokenConfigs[token];

    emit RemoveUnderlying(token);
  }

  /// @notice Return if the given token address is acceptable as underlying token.
  /// @param token The token address to check.
  function isAcceptUnderlying(address token) external view returns (bool) {
    return underlyingTokenConfigs[token].isAccept;
  }
}
