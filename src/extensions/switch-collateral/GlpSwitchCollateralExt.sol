// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERc20.sol";

// interfaces
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ISwitchCollateralExt } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralExt.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxVault } from "@hmx/interfaces/gmx/IGmxVault.sol";

contract GlpSwitchCollateralExt is Ownable, ISwitchCollateralExt {
  using SafeERC20 for ERC20;

  error GlpSwitchCollateralExt_Forbidden();
  error GlpSwitchCollateralExt_NotSupported();

  IConfigStorage public configStorage;

  ERC20 public weth;
  ERC20 public sGlp;
  IGmxGlpManager public glpManager;
  IGmxVault public gmxVault;
  IGmxRewardRouterV2 public gmxRewardRouter;

  constructor(
    IConfigStorage _configStorage,
    address _weth,
    address _sGlp,
    address _glpManager,
    address _gmxVault,
    address _gmxRewardRouter
  ) {
    configStorage = _configStorage;
    weth = ERC20(_weth);
    sGlp = ERC20(_sGlp);
    glpManager = IGmxGlpManager(_glpManager);
    gmxVault = IGmxVault(_gmxVault);
    gmxRewardRouter = IGmxRewardRouterV2(_gmxRewardRouter);
  }

  function run(
    address _tokenIn,
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minAmountOut,
    bytes calldata _data
  ) external override returns (uint256 _amountOut) {
    // Check
    if (_tokenOut == address(sGlp)) {
      _amountOut = _toGlp(_tokenIn, _amountIn, _minAmountOut, _data);
    } else if (_tokenIn == address(sGlp)) {
      _amountOut = _fromGlp(_tokenOut, _amountIn, _minAmountOut, _data);
    } else {
      revert GlpSwitchCollateralExt_NotSupported();
    }
  }

  function _toGlp(
    address _tokenIn,
    uint256 _amountIn,
    uint256 /* _minAmountOut */,
    bytes memory _data
  ) internal returns (uint256 _amountOut) {
    if (!gmxVault.whitelistedTokens(_tokenIn)) {
      // If tokenIn is not in GMX's Vault, then swap it to WETH first.
      // However, _tokenIn can be a primative ERC20 or a yield bearing token
      // so we will rely on the injected sub-extension to handle this.

      // Decode data
      (ISwitchCollateralExt _switchCollateralExt, bytes memory _switchCollateralExtData) = abi.decode(
        _data,
        (ISwitchCollateralExt, bytes)
      );

      // Check
      // Check if _switchCollateralExt is allowed
      if (!configStorage.switchCollateralExts(_tokenIn, address(weth))) revert GlpSwitchCollateralExt_Forbidden();

      // Transfer to _switchCollateralExt
      ERC20(_tokenIn).safeTransfer(address(_switchCollateralExt), _amountIn);

      // Run _switchCollateralExt
      _amountOut = _switchCollateralExt.run(_tokenIn, address(weth), _amountIn, 0, _switchCollateralExtData);

      // Re-assign _tokenIn to be WETH
      _tokenIn = address(weth);
    }

    ERC20(_tokenIn).approve(address(glpManager), _amountOut);
    _amountOut = gmxRewardRouter.mintAndStakeGlp(address(_tokenIn), _amountOut, 0, 0);

    // Transfer sGlp to out to msg.sender
    sGlp.safeTransfer(msg.sender, _amountOut);
  }

  function _fromGlp(
    address _tokenOut,
    uint256 _amountIn,
    uint256 /* _minAmountOut */,
    bytes memory _data
  ) internal returns (uint256 _amountOut) {
    address _backFromGlp = _tokenOut;
    bool _executeSubExt = false;
    if (!gmxVault.whitelistedTokens(_tokenOut)) {
      // if _tokenOut is not in GMX's Vault, then force it to be WETH first.
      // And we will need to execute sub-extension
      _backFromGlp = address(weth);
      _executeSubExt = true;
    }

    _amountOut = gmxRewardRouter.unstakeAndRedeemGlp(_backFromGlp, _amountIn, 0, address(this));
    if (_executeSubExt) {
      // If tokenOut is not in GMX's Vault, then we will rely on the injected sub-extension to handle this.

      // Decode data
      (ISwitchCollateralExt _switchCollateralExt, bytes memory _switchCollateralExtData) = abi.decode(
        _data,
        (ISwitchCollateralExt, bytes)
      );

      // Check
      // Check if _switchCollateralExt is allowed
      if (!configStorage.switchCollateralExts(address(weth), _tokenOut)) revert GlpSwitchCollateralExt_Forbidden();

      // Transfer to _switchCollateralExt
      weth.safeTransfer(address(_switchCollateralExt), _amountOut);

      // Run _switchCollateralExt
      _amountOut = _switchCollateralExt.run(address(weth), _tokenOut, _amountOut, 0, _switchCollateralExtData);
    }
  }
}
