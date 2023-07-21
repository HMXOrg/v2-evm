// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// bases
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// interfaces
import { ISwitchCollateralRouter } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralRouter.sol";
import { ISwitchCollateralExt } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralExt.sol";

contract SwitchCollateralRouter is Ownable, ISwitchCollateralRouter {
  using SafeERC20 for ERC20;

  error SwitchCollateralRouter_NotFoundSwitchCollateralExt();

  mapping(address tokenIn => mapping(address tokenOut => ISwitchCollateralExt)) public switchCollateralExtOf;

  event LogSetSwitchCollateralExt(
    address indexed tokenIn,
    address indexed tokenOut,
    ISwitchCollateralExt prevSwitchCollateralExt,
    ISwitchCollateralExt switchCollateralExt
  );

  function execute(uint256 _amount, address[] calldata _path) external returns (uint256 _amountOut) {
    for (uint i = 0; i < _path.length - 1; i++) {
      (address _tokenIn, address _tokenOut) = (_path[i], _path[i + 1]);
      ISwitchCollateralExt _switchCollateralExt = switchCollateralExtOf[_tokenIn][_tokenOut];

      // Check if the switch collateral extension is registered.
      if (address(_switchCollateralExt) == address(0)) revert SwitchCollateralRouter_NotFoundSwitchCollateralExt();

      // Execute the switch collateral extension.
      ERC20(_tokenIn).safeTransfer(address(_switchCollateralExt), _amount);
      _amount = _switchCollateralExt.run(_tokenIn, _tokenOut, _amount);
    }

    // Return the amount of the last token.
    ERC20(_path[_path.length - 1]).safeTransfer(msg.sender, _amount);

    return _amount;
  }

  /*
   * Setters
   */
  function setSwitchCollateralExt(
    address _tokenIn,
    address _tokenOut,
    address _switchCollateralExt
  ) external onlyOwner {
    emit LogSetSwitchCollateralExt(
      _tokenIn,
      _tokenOut,
      switchCollateralExtOf[_tokenIn][_tokenOut],
      ISwitchCollateralExt(_switchCollateralExt)
    );
    switchCollateralExtOf[_tokenIn][_tokenOut] = ISwitchCollateralExt(_switchCollateralExt);
  }
}
