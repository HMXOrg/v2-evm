// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "./BaseIntTest_SetMarkets.i.sol";

contract BaseIntTest_WithActions is BaseIntTest_SetMarkets {
  /**
   * Liquidity
   */

  /// @notice Helper function to create liquidity and execute order
  /// @param _liquidityProvider liquidity provider address
  /// @param _tokenIn liquidity token to add
  /// @param _amountIn amount of token to provide
  /// @param _executionFee execution fee
  /// @param _priceData Pyth's price data
  function addLiquidity(
    address _liquidityProvider,
    address _tokenIn,
    uint256 _amountIn,
    uint256 _executionFee,
    bytes[] memory _priceData
  ) internal {
    vm.prank(_liquidityProvider);
    /// note: _minOut always 0 to make test passed
    /// note: _shouldWrap treat as false when only GLP could be liquidity
    liquidityHandler.createAddLiquidityOrder{ value: _executionFee }(_tokenIn, _amountIn, 0, _executionFee, false);

    liquidityHandler.executeOrder(_liquidityProvider, 0, _priceData);
  }

  /// @notice Helper function to remove liquidity and execute order
  /// @param _liquidityProvider liquidity provider address
  /// @param _tokenOut liquidity token to remove
  /// @param _amountIn PLP amount to remove
  /// @param _executionFee execution fee
  /// @param _priceData Pyth's price data
  function removeLiquidity(
    address _liquidityProvider,
    address _tokenOut,
    uint256 _amountIn,
    uint256 _executionFee,
    bytes[] calldata _priceData
  ) internal {
    vm.prank(_liquidityProvider);
    /// note: _minOut always 0 to make test passed
    /// note: _shouldWrap treat as false when only GLP could be liquidity
    liquidityHandler.createRemoveLiquidityOrder{ value: _executionFee }(_tokenOut, _amountIn, 0, _executionFee, false);

    liquidityHandler.executeOrder(_liquidityProvider, 0, _priceData);
  }
}
