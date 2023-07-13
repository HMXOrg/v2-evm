// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// interfaces
import { ISwitchCollateralExt } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralExt.sol";

contract UniUniversalRouterSwitchCollateralExt is ISwitchCollateralExt {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  error UniUniversalRouterSwitchCollateralExt_BadSelector();
  error UniUniversalRouterSwitchCollateralExt_SwapFailed();

  address public universalRouter;

  constructor(address _universalRouter) {
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
    if (_selector != 0x24856bc3 || _selector != 0x3593564c) revert UniUniversalRouterSwitchCollateralExt_BadSelector();

    // Interaction
    // Approve tokenIn
    ERC20Upgradeable(_tokenIn).safeApprove(address(universalRouter), _amountIn);

    uint256 _balanceBefore = ERC20Upgradeable(_tokenOut).balanceOf(address(this));
    (bool _success, ) = universalRouter.call(_data);
    if (!_success) revert UniUniversalRouterSwitchCollateralExt_SwapFailed();
    _amountOut = ERC20Upgradeable(_tokenOut).balanceOf(address(this)) - _balanceBefore;

    // Reset approval
    ERC20Upgradeable(_tokenIn).safeApprove(address(universalRouter), 0);

    // Transfer tokenOut back to msg.sender
    ERC20Upgradeable(_tokenOut).safeTransfer(msg.sender, _amountOut);
  }
}
