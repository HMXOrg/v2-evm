// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

/// @title Liquidity Tester
/// @notice This Tester help to check state after user interact with LiquidityHandler / LiquidityService
contract LiquidityTester is StdAssertions {
  /**
   * Structs
   */
  struct LiquidityExpectedData {
    address token;
    uint256 lpTotalSupply;
    uint256 tokenLiquidity;
    uint256 tokenBalance;
    uint256 fee;
    uint256 executionFee;
  }

  /**
   * States
   */
  IPLPv2 plp;

  IVaultStorage vaultStorage;
  IPerpStorage perpStorage;

  address liquidityHandler;

  constructor(IPLPv2 _plp, IVaultStorage _vaultStorage, IPerpStorage _perpStorage, address _liquidityHandler) {
    plp = _plp;
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
    liquidityHandler = _liquidityHandler;
  }

  /// @notice Assert function when PLP provider add / remove liquidity
  /// @dev This function will check
  ///      - PLPv2 total supply
  ///      - Execution fee in handler, if address is valid
  ///      - PLP liquidity in VaultStorage's state
  ///      - Total token amount in VaultStorage's state
  ///      - Fee is VaultStorage's state
  ///      - Token balance in VaultStorage
  function assertLiquidityInfo(LiquidityExpectedData memory _expectedData) external {
    address _token = _expectedData.token;
    uint256 _totalBalance = _expectedData.tokenBalance;

    // Check PLPv2 total supply
    assertEq(plp.totalSupply(), _expectedData.lpTotalSupply, "PLP Total supply");

    // Deposit / Withdraw fee
    // note: to integrate this tester with LiquidityService
    if (liquidityHandler != address(0)) {
      assertEq(liquidityHandler.balance, _expectedData.executionFee);
    }

    // Check VaultStorage's state
    assertEq(vaultStorage.plpLiquidity(_token), _expectedData.tokenLiquidity, "PLP token liquidity amount");
    assertEq(vaultStorage.totalAmount(_token), _totalBalance, "Token balance");
    assertEq(vaultStorage.fees(_token), _expectedData.fee, "Fee in Token");

    // Check token balance
    assertEq(IERC20(_token).balanceOf(address(vaultStorage)), _totalBalance, "Vault token balance");
  }
}
