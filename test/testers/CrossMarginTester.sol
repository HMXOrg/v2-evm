// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

/// @title CrossMargin Tester
/// @notice This Tester help to check information after user interact with CrossMarginHandler / CrossMarginService
contract CrossMarginTester is StdAssertions {
  /**
   * States
   */
  IVaultStorage vaultStorage;
  IPerpStorage perpStorage;

  address crossMarginHandler;

  constructor(IVaultStorage _vaultStorage, IPerpStorage _perpStorage, address _crossMarginHandler) {
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
    crossMarginHandler = _crossMarginHandler;
  }

  struct TraderAssertData {
    uint256 tokenBalance;
  }

  struct VaultStorageExpectedData {
    uint256 traderBalance;
    uint8 tokenLength;
  }

  struct CrossMarginExpectedData {
    address trader;
    uint256 traderRemainingBalance;
    uint256 vaultTraderBalance;
    uint256 vaultTokenBalance;
    ERC20 token;
  }

  /// @notice Assert function when Trader interact deposit / withdraw collateral
  /// @dev This function will check
  ///       - Token balance
  ///         - Account
  ///         - VaultStorage
  ///         - CrossMarginHandler, if address is valid
  ///       - VaultStorage's state
  ///         - Trader balance
  ///         - Trader token list
  ///         - Total Amount - should be same with VaultStorage token balanceOf
  function assertCrossMarginInfo(TraderAssertData memory _tdata, CrossMarginAssertData memory _data) internal {
    address _tokenAddress = address(_data.token);
    uint256 _vaultTokenBalance = _data.vaultTokenBalance;
    // Check token balance
    assertEq(_data.token.balanceOf(_data.trader), _tdata.tokenBalance, "Trader token balance in Wallet");
    assertEq(_data.token.balanceOf(address(vaultStorage)), _vaultTokenBalance, "Token balance in VaultStorage");

    // note: to integrate this tester with CrossMarginService
    if (crossMarginHandler != address(0)) {
      assertEq(_data.token.balanceOf(crossMarginHandler), 0, "Token balance in CrossMarginHandler");
    }

    // Check vault storage state
    assertEq(vaultStorage.totalAmount(_tokenAddress), _vaultTokenBalance, "Total amount of Token in VaultStorage");
    assertEq(
      vaultStorage.traderBalances(_data.trader, _tokenAddress),
      _data.vaultTraderBalance,
      "Total amount of Token in VaultStorage"
    );
  }

  /**
  
    TraderAssertData memory _data;


    _data.tokenBalance = 10 ether;
  

    assertCrossMarginInfo();
   */
}
