// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// bases
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { ERC4626 } from "@solmate/mixins/ERC4626.sol";

// interfaces
import { IDexter } from "@hmx/extensions/dexters/interfaces/IDexter.sol";

contract Erc4626Dexter is Ownable, IDexter {
  using SafeTransferLib for ERC20;

  // Errors
  error Erc4626Dexter_Forbidden();
  error Erc4626Dexter_NotSupported();

  // Configs
  mapping(address token => bool isSupported) public supportedTokens;

  function setSupportedToken(address _token, bool _supported) external onlyOwner {
    supportedTokens[_token] = _supported;
  }

  /// @notice Run the extension logic.
  /// @dev This function supports both switching to and from sGlp.
  /// @param _tokenIn The token to switch from.
  /// @param _tokenOut The token to switch to.
  /// @param _amountIn The amount of _tokenIn to switch.
  function run(address _tokenIn, address _tokenOut, uint256 _amountIn) external override returns (uint256 _amountOut) {
    // Check
    if (supportedTokens[_tokenIn]) {
      ERC4626 _tokenIn4626 = ERC4626(_tokenIn);
      if (_tokenOut != address(_tokenIn4626.asset())) revert Erc4626Dexter_NotSupported();
      _amountOut = _withdraw(_tokenIn, _amountIn);
    } else if (supportedTokens[_tokenOut]) {
      ERC4626 _tokenOut4626 = ERC4626(_tokenOut);
      if (_tokenIn != address(_tokenOut4626.asset())) revert Erc4626Dexter_NotSupported();
      _amountOut = _deposit(_tokenOut, _amountIn);
    } else {
      revert Erc4626Dexter_NotSupported();
    }
  }

  /// @notice Withdraw from ERC4626.
  /// @param _tokenIn The ERC4626 token to withdraw from.
  /// @param _amountIn The amount of _tokenIn to withdraw.
  function _withdraw(address _tokenIn, uint256 _amountIn) internal returns (uint256 _amountOut) {
    _amountOut = ERC4626(_tokenIn).redeem(_amountIn, msg.sender, address(this));
  }

  /// @notice Deposit to ERC4626.
  /// @param _tokenOut The ERC4626 token to deposit to.
  /// @param _amountIn The amount of underlying asset to deposit.
  function _deposit(address _tokenOut, uint256 _amountIn) internal returns (uint256 _amountOut) {
    ERC20 _asset = ERC20(ERC4626(_tokenOut).asset());
    _asset.approve(_tokenOut, _amountIn);
    _amountOut = ERC4626(_tokenOut).deposit(_amountIn, msg.sender);
  }
}
