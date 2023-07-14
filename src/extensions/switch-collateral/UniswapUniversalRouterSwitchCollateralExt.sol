// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// interfaces
import { IPermit2 } from "@hmx/interfaces/uniswap/IPermit2.sol";
import { ISwitchCollateralExt } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralExt.sol";

contract UniswapUniversalRouterSwitchCollateralExt is ISwitchCollateralExt {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  error UniswapUniversalRouterSwitchCollateralExt_BadSelector();
  error UniswapUniversalRouterSwitchCollateralExt_SwapFailed();

  IPermit2 public permit2;
  address public universalRouter;

  constructor(address _permit2, address _universalRouter) {
    permit2 = IPermit2(_permit2);
    universalRouter = _universalRouter;
  }

  function run(
    address _tokenIn,
    address _tokenOut,
    uint256 _amountIn,
    uint256 /* _minAmountOut */,
    bytes calldata _data
  ) external override returns (uint256 _amountOut) {
    // Check
    bytes4 _selector = bytes4(_data[:4]);
    // 0x24856bc3 => UniversalRouter.execute without deadline
    // 0x3593564c => UniversalRouter.execute with deadline
    if (_selector != 0x24856bc3 || _selector != 0x3593564c)
      revert UniswapUniversalRouterSwitchCollateralExt_BadSelector();

    // Approve tokenIn to Permit2 if needed
    ERC20Upgradeable _tIn = ERC20Upgradeable(_tokenIn);
    if (_tIn.allowance(address(this), address(permit2)) < _amountIn)
      _tIn.safeApprove(address(permit2), type(uint256).max);
    // Approve UniUniversalRouter to spend tokenIn in Permit2 if needed
    (uint160 _allowance, , ) = permit2.allowance(address(this), _tokenIn, universalRouter);
    if (_allowance < uint160(_amountIn))
      permit2.approve(_tokenIn, universalRouter, type(uint160).max, type(uint48).max);

    uint256 _balanceBefore = ERC20Upgradeable(_tokenOut).balanceOf(address(this));
    (bool _success, ) = universalRouter.call(_data);
    if (!_success) revert UniswapUniversalRouterSwitchCollateralExt_SwapFailed();
    _amountOut = ERC20Upgradeable(_tokenOut).balanceOf(address(this)) - _balanceBefore;

    // Transfer tokenOut back to msg.sender
    ERC20Upgradeable(_tokenOut).safeTransfer(msg.sender, _amountOut);
  }
}
