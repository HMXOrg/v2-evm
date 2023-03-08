// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

contract MockVaultStorage {
  mapping(address => mapping(address => uint256)) public traderBalances;
  mapping(address => address[]) public traderTokens;

  uint256 public plpLiquidityDebtUSDE30;

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function setTraderBalance(address _subAccount, address _token, uint256 _amount) external {
    traderBalances[_subAccount][_token] = _amount;
  }

  function setTraderTokens(address _subAccount, address _token) external {
    traderTokens[_subAccount].push(_token);
  }

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  function getTraderTokens(address _subAccount) external view returns (address[] memory) {
    return traderTokens[_subAccount];
  }
}
