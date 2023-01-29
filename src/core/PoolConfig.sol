// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {IteratableAddressList} from "../libraries/IteratableAddressList.sol";

contract PoolConfig is Owned {
  using IteratableAddressList for IteratableAddressList.List;

  error PoolConfig_BadLen();
  error PoolConfig_BadArgs();

  // Underlying configurations
  struct UnderlyingConfig {
    bool isAccept;
    uint8 decimals;
    uint64 weight;
  }

  IteratableAddressList.List public underlyingTokens;
  mapping(address => UnderlyingConfig) public underlyingConfigs;
  uint64 public totalUnderlyingWeight;

  // Oracle configurations
  uint64 public defaultOracleStaleTime;
  // Map between action id and stale time.
  mapping(bytes32 => uint64) public actionStaleTimes;

  event AddOrUpdateTokenConfigs(
    address token, UnderlyingConfig prevConfig, UnderlyingConfig newConfig
  );
  event RemoveUnderlying(address token);
  event SetDefaultOracleStaleTime(uint64 prevStaleTime, uint64 newStaleTime);
  event SetActionStaleTime(
    bytes32 actionId, uint64 prevStaleTime, uint64 newStaleTime
  );

  constructor(uint64 _defaultOracleStaleTime) {
    defaultOracleStaleTime = _defaultOracleStaleTime;
  }

  /// @notice Add or update underlying.
  /// @dev This function only allows to add new token or update existing token,
  /// any atetempt to remove token will be reverted.
  /// @param tokens The token addresses to set.
  /// @param configs The token configs to set.
  function addOrUpdateUnderlying(
    address[] calldata tokens,
    UnderlyingConfig[] calldata configs
  ) external onlyOwner {
    if (tokens.length != configs.length) {
      revert PoolConfig_BadLen();
    }

    for (uint256 i = 0; i < tokens.length;) {
      // Enforce that isAccept must be true to prevent
      // removing underlying token through this function.
      if (!configs[i].isAccept) revert PoolConfig_BadArgs();

      // If UnderlyingConfig.isAccept is previously false,
      // then it is a new token to be added.
      if (!underlyingConfigs[tokens[i]].isAccept) {
        underlyingTokens.add(tokens[i]);
      }

      // Log
      emit AddOrUpdateTokenConfigs(
        tokens[i], underlyingConfigs[tokens[i]], configs[i]
        );

      // Update totalUnderlyingWeight accordingly
      totalUnderlyingWeight = (
        totalUnderlyingWeight - underlyingConfigs[tokens[i]].weight
      ) + configs[i].weight;
      underlyingConfigs[tokens[i]] = configs[i];

      unchecked {
        ++i;
      }
    }
  }

  /// @notice Remove underlying token.
  /// @param token The token address to remove.
  function removeUnderlying(address token) external onlyOwner {
    // Update totalTokenWeight
    totalUnderlyingWeight -= underlyingConfigs[token].weight;

    // Delete token from underlyingTokens list
    underlyingTokens.remove(token, underlyingTokens.getPreviousOf(token));
    // Delete underlying config
    delete underlyingConfigs[token];

    emit RemoveUnderlying(token);
  }

  /// @notice Return if the given token address is acceptable as underlying token.
  /// @param token The token address to check.
  function isAcceptUnderlying(address token) external view returns (bool) {
    return underlyingConfigs[token].isAccept;
  }

  /// @notice Return the decimals of the given token address.
  /// @param token The token address to query the decimals.
  function getDecimalsOf(address token) external view returns (uint8) {
    return underlyingConfigs[token].decimals;
  }

  /// @notice Return the next underlying token address.
  /// @dev This uses to traverse all underlying tokens.
  /// @param token The token address to query the next token. Can also be START and END.
  function getNextUnderlyingOf(address token) external view returns (address) {
    return underlyingTokens.getNextOf(token);
  }

  /// @notice Set default oracle stale time.
  /// @param newDefaultOracleStaleTime The new default stale time to set.
  function setDefaultOracleStale(uint64 newDefaultOracleStaleTime)
    external
    onlyOwner
  {
    emit SetDefaultOracleStaleTime(
      defaultOracleStaleTime, newDefaultOracleStaleTime
      );
    defaultOracleStaleTime = newDefaultOracleStaleTime;
  }

  /// @notice Set oracle stale time for the given action id.
  /// @param actionId The action id to set.
  /// @param newStaleTime The new stale time to set.
  function setActionStaleTime(bytes32 actionId, uint64 newStaleTime)
    external
    onlyOwner
  {
    emit SetActionStaleTime(actionId, actionStaleTimes[actionId], newStaleTime);
    actionStaleTimes[actionId] = newStaleTime;
  }

  /// @notice Get oracle stale time for the given action id.
  /// @param actionId The action id to get.
  function getActionStaleTime(bytes32 actionId) external view returns (uint64) {
    uint64 staleTime = actionStaleTimes[actionId];
    if (staleTime == 0) {
      return defaultOracleStaleTime;
    }
    return staleTime;
  }
}
