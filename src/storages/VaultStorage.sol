// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IVaultStorage } from "./interfaces/IVaultStorage.sol";

/// @title VaultStorage
/// @notice storage contract to do accounting for token, and also hold physical tokens
contract VaultStorage is IVaultStorage {
  // liquidity provider address => token => amount
  mapping(address => mapping(address => uint256))
    public liquidityProviderBalances;
  mapping(address => address[]) public liquidityProviderTokens;

  mapping(address => uint256) totalLiquidityTokens;

  // fee in token unit
  mapping(address => uint256) fees;

  // trader address (with sub-account) => token => amount
  mapping(address => mapping(address => uint256)) public traderBalances;
  mapping(address => address[]) public traderTokens;

  function setLiquidityProviderBalances(
    address _lpProvider,
    address _token,
    uint256 _amount
  ) external {
    liquidityProviderBalances[_lpProvider][_token] = _amount;
  }

  function setLiquidityProviderTokens(
    address _lpProvider,
    address _token
  ) external {
    liquidityProviderTokens[_lpProvider].push(_token);
  }

  // TODO modifier?
  function addFee(address _token, uint256 _amount) external {
    fees[_token] += _amount;
  }

  function getLiquidityProviderTokens(
    address _token
  ) external view returns (address[] memory) {
    return liquidityProviderTokens[_token];
  }

  function getLiquidityProviderBalances(
    address _lpProvider,
    address _token
  ) external view returns (uint256) {
    return liquidityProviderBalances[_lpProvider][_token];
  }

  function getTraderTokens(
    address _trader
  ) external view returns (address[] memory) {
    return traderTokens[_trader];
  }

  function getTotalLiquidityTokens(
    address _token
  ) external view returns (uint256) {
    return totalLiquidityTokens[_token];
  }
}
