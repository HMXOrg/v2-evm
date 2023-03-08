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

  struct LiquidityAssertData {
    address token;
    uint256 lpTotalSupply;
    uint256 tokenBalance;
    uint256 fee;
    uint256 executionFee;
  }

  /// @notice Assert function when PLP provider interact with Liquidity handler
  /// @dev This function will check
  ///      - PLP total supply
  ///      - PLP liquidity
  ///      - Token balance and Physical token balance
  ///      - Execution fee in handler, if address is valid
  ///      - Tax Fee
  function assertLiquidityInfo(LiquidityAssertData memory _data) internal {
    address _token = _data.token;
    uint256 _totalBalance = _data.tokenBalance;

    assertEq(plp.totalSupply(), _data.lpTotalSupply, "PLP Total supply");

    assertEq(vaultStorage.plpLiquidity(_token), _totalBalance, "PLP token liquidity amount");
    assertEq(vaultStorage.totalAmount(_token), _totalBalance, "Token balance");

    // check physical token
    assertEq(IERC20(_token).balanceOf(address(vaultStorage)), _totalBalance);

    // Deposit / Withdraw fee
    if (liquidityHandler != address(0)) {
      assertEq(liquidityHandler.balance, _data.executionFee);
    }

    // Tax Fee
    assertEq(vaultStorage.fees(_token), _data.fee);
  }
}
