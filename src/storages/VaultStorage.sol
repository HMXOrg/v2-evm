// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IVaultStorage } from "./interfaces/IVaultStorage.sol";

/// @title VaultStorage
/// @notice storage contract to do accounting for token, and also hold physical tokens
contract VaultStorage is IVaultStorage {
  uint256 public plpTotalLiquidityUSD;
  mapping(address => uint256) public plpLiquidityUSD; //token => PLPValueInUSD
  mapping(address => uint256) public plpLiquidity; // token => PLPTokenAmount

  // fee in token unit
  mapping(address => uint256) public fees;

  // trader address (with sub-account) => token => amount
  mapping(address => mapping(address => uint256)) public traderBalances;
  mapping(address => address[]) public traderTokens;

  function getTraderTokens(
    address _trader
  ) external view returns (address[] memory) {
    return traderTokens[_trader];
  }

  // TODO modifier?
  function addFee(address _token, uint256 _amount) external {
    fees[_token] += _amount;
  }

  // TODO modifier?
  function addPLPLiquidityUSD(address _token, uint256 amount) external {
    plpLiquidityUSD[_token] += amount;
  }

  // TODO modifier?
  function addPLPTotalLiquidityUSD(uint256 _liquidity) external {
    plpTotalLiquidityUSD += _liquidity;
  }

  // TODO modifier?
  function addPLPLiquidity(address _token, uint256 _amount) external {
    plpLiquidity[_token] += _amount;
  }
}
