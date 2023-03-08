// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_SetOracle } from "@hmx-test/integration/BaseIntTest_SetOracle.i.sol";

contract BaseIntTest_WithActions is BaseIntTest_SetOracle {
  /**
   * Liquidity
   */

  /// @notice Helper function to create liquidity and execute order via handler
  /// @param liquidityProvider liquidity provider address
  /// @param tokenIn liquidity token to add
  /// @param amountIn amount of token to provide
  /// @param executionFee execution fee
  /// @param priceData Pyth's price data
  function addLiquidity(
    address liquidityProvider,
    ERC20 tokenIn,
    uint256 amountIn,
    uint256 executionFee,
    bytes[] memory priceData
  ) internal {
    vm.startPrank(liquidityProvider);
    tokenIn.approve(address(liquidityHandler), amountIn);
    /// note: minOut always 0 to make test passed
    /// note: shouldWrap treat as false when only GLP could be liquidity
    liquidityHandler.createAddLiquidityOrder{ value: executionFee }(address(tokenIn), amountIn, 0, executionFee, false);
    vm.stopPrank();

    liquidityHandler.executeOrder(liquidityProvider, 0, priceData);
  }

  /// @notice Helper function to remove liquidity and execute order via handler
  /// @param liquidityProvider liquidity provider address
  /// @param tokenOut liquidity token to remove
  /// @param amountIn PLP amount to remove
  /// @param executionFee execution fee
  /// @param priceData Pyth's price data
  function removeLiquidity(
    address liquidityProvider,
    ERC20 tokenOut,
    uint256 amountIn,
    uint256 executionFee,
    bytes[] calldata priceData
  ) internal {
    vm.startPrank(liquidityProvider);
    tokenOut.approve(address(liquidityHandler), amountIn);
    /// note: minOut always 0 to make test passed
    /// note: shouldWrap treat as false when only GLP could be liquidity
    liquidityHandler.createRemoveLiquidityOrder{ value: executionFee }(
      address(tokenOut),
      amountIn,
      0,
      executionFee,
      false
    );
    vm.stopPrank();

    liquidityHandler.executeOrder(liquidityProvider, 0, priceData);
  }

  /**
   * Cross Margin
   */
  /// @notice Helper function to deposit collateral via handler
  /// @param account Trader's address
  /// @param subAccountId Trader's sub-account ID
  /// @param collateralToken Collateral token to deposit
  /// @param depositAmount amount to deposit
  function depositCollateral(
    address account,
    uint8 subAccountId,
    ERC20 collateralToken,
    uint256 depositAmount
  ) internal {
    vm.startPrank(account);
    collateralToken.approve(address(crossMarginHandler), depositAmount);
    crossMarginHandler.depositCollateral(account, subAccountId, address(collateralToken), depositAmount);
    vm.stopPrank();
  }

  /// @notice Helper function to withdraw collateral via handler
  /// @param account Trader's address
  /// @param subAccountId Trader's sub-account ID
  /// @param collateralToken Collateral token to withdraw
  /// @param withdrawAmount amount to withdraw
  /// @param priceData Pyth's price data
  function withdrawCollateral(
    address account,
    uint8 subAccountId,
    ERC20 collateralToken,
    uint256 withdrawAmount,
    bytes[] calldata priceData
  ) internal {
    vm.prank(account);
    crossMarginHandler.withdrawCollateral(account, subAccountId, address(collateralToken), withdrawAmount, priceData);
  }

  /**
   * Trade
   */
}
