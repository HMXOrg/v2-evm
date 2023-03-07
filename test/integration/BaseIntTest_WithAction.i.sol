// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "./BaseIntTest_SetMarkets.i.sol";

contract BaseIntTest_WithAction is BaseIntTest_SetMarkets {
  function createLiquidityOrder(
    address _caller,
    address _tokenIn,
    uint256 _amountIn,
    uint256 _executionFee,
    bool _shouldWrap
  ) internal {
    vm.prank(_caller);
    liquidityHandler.createAddLiquidityOrder(_tokenIn, _amountIn, 0, _executionFee, _shouldWrap);

    // liquidityHandler.executeOrder(_caller, 0, _priceData);
  }
}
