// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

// lib
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// interface
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract RebalanceHLPService is OwnableUpgradeable, IRebalanceHLPService {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable public sglp;
  IGmxRewardRouterV2 public rewardRouter;
  IGmxGlpManager public glpManager;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;

  modifier onlyWhitelisted() {
    configStorage.validateServiceExecutor(address(this), msg.sender);
    _;
  }

  function initialize(
    address _sglp,
    address _rewardRouter,
    address _glpManager,
    address _vaultStorage,
    address _configStorage
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    sglp = IERC20Upgradeable(_sglp);
    rewardRouter = IGmxRewardRouterV2(_rewardRouter);
    glpManager = IGmxGlpManager(_glpManager);
    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
  }

  function executeWithdrawGLP(
    ExecuteWithdrawParams[] calldata _params
  ) external onlyWhitelisted returns (WithdrawGLPResult[] memory returnData) {
    // SLOADS, gas opt.
    IVaultStorage _vaultStorage = vaultStorage;
    IERC20Upgradeable _sglp = sglp;

    returnData = new WithdrawGLPResult[](_params.length);

    for (uint256 i = 0; i < _params.length; ) {
      // Set default for return data
      returnData[i].token = _params[i].token;
      returnData[i].amount = 0;
      // get token from vault, remove HLP liq.
      _vaultStorage.pushToken(address(_sglp), address(this), _params[i].glpAmount);
      _vaultStorage.removeHLPLiquidity(address(_sglp), _params[i].glpAmount);

      // unstake n redeem GLP
      _sglp.safeIncreaseAllowance(address(glpManager), _params[i].glpAmount);
      returnData[i].amount += rewardRouter.unstakeAndRedeemGlp(
        _params[i].token,
        _params[i].glpAmount,
        _params[i].minOut,
        address(_vaultStorage)
      );

      // update accounting
      _vaultStorage.pullToken(_params[i].token);
      _vaultStorage.addHLPLiquidity(_params[i].token, returnData[i].amount);
      unchecked {
        ++i;
      }
    }
  }

  function executReinvestNonHLP(
    ExecuteReinvestParams[] calldata _params
  ) external onlyWhitelisted returns (uint256 receivedGlp) {
    // SLOADS, gas opt.
    IERC20Upgradeable _sglp = sglp;
    IVaultStorage _vaultStorage = vaultStorage;

    receivedGlp = 0;
    for (uint256 i = 0; i < _params.length; ) {
      // declare token
      IERC20Upgradeable _token = IERC20Upgradeable(_params[i].token);

      // get Token from vault, remove HLP liq.
      _vaultStorage.pushToken(_params[i].token, address(this), _params[i].amount);
      _vaultStorage.removeHLPLiquidity(_params[i].token, _params[i].amount);

      // mint n stake, sanity check
      _token.safeIncreaseAllowance(address(glpManager), _params[i].amount);
      receivedGlp += rewardRouter.mintAndStakeGlp(
        _params[i].token,
        _params[i].amount,
        _params[i].minAmountOutUSD,
        _params[i].minAmountOutGlp
      );
      unchecked {
        ++i;
      }
    }

    // send accum GLP back to vault
    _sglp.safeTransfer(address(vaultStorage), receivedGlp);

    // send token back to vault, add HLP liq.
    _vaultStorage.pullToken(address(_sglp));
    _vaultStorage.addHLPLiquidity(address(_sglp), receivedGlp);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
