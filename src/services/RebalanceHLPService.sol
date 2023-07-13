// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

contract RebalanceHLPService is OwnableUpgradeable, IRebalanceHLPService {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable public sglp;
  ICalculator public calculator;

  IVaultStorage public vaultStorage;
  IGmxRewardRouterV2 public rewardRouter;
  IGmxGlpManager public glpManager;

  mapping(address => bool) public whitelistExecutors;

  uint16 public minTvlBPS;
  uint16 public constant BPS = 100_00;

  event LogSetMinTvlBPS(uint16 _oldMinTvlBps, uint16 _newMinTvlBps);
  event LogSetWhitelistExecutor(address indexed _account, bool _active);

  modifier onlyWhitelisted() {
    // if not whitelist
    if (!whitelistExecutors[msg.sender]) {
      revert RebalanceHLPService_OnlyWhitelisted();
    }
    _;
  }

  function initialize(
    address _sglp,
    address _rewardRouter,
    address _vaultStorage,
    address _glpManager,
    address _calculator,
    uint16 _minTvlBPS
  ) external initializer {
    __Ownable_init();
    sglp = IERC20Upgradeable(_sglp);
    rewardRouter = IGmxRewardRouterV2(_rewardRouter);
    vaultStorage = IVaultStorage(_vaultStorage);
    glpManager = IGmxGlpManager(_glpManager);
    calculator = ICalculator(_calculator);
    minTvlBPS = _minTvlBPS;
  }

  function setWhiteListExecutor(address _executor, bool _active) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPService_AddressIsZero();
    }
    whitelistExecutors[_executor] = _active;
    emit LogSetWhitelistExecutor(_executor, _active);
  }

  function setMinTvlBPS(uint16 _newMinTvlBps) external onlyOwner {
    if (_newMinTvlBps == 0) {
      revert RebalanceHLPService_AmountIsZero();
    }
    emit LogSetMinTvlBPS(minTvlBPS, _newMinTvlBps);
    minTvlBPS = _newMinTvlBps;
  }

  function execute(ExecuteParams[] calldata _params) external onlyWhitelisted returns (uint256 receivedGlp) {
    if (_params.length == 0) revert RebalanceHLPService_ParamsIsEmpty();
    // SLOADS, gas opt.
    ICalculator _calculator = calculator;
    IERC20Upgradeable _sglp = sglp;
    IVaultStorage _vaultStorage = vaultStorage;
    address _glpManager = address(glpManager);

    uint256 hlpValueBefore = _calculator.getHLPValueE30(true);
    receivedGlp = 0;
    for (uint256 i = 0; i < _params.length; ) {
      // ignore if either value is zero
      if (_params[i].token == address(0) || _params[i].amount == 0) {
        continue;
      }
      // declare token
      IERC20Upgradeable _token = IERC20Upgradeable(_params[i].token);

      // get Token from vault, remove HLP liq.
      _vaultStorage.pushToken(_params[i].token, address(this), _params[i].amount);
      _vaultStorage.removeHLPLiquidity(_params[i].token, _params[i].amount);

      // mint n stake
      // user increaseAllowance instead, as approve() is deprecated.
      _token.safeIncreaseAllowance(address(glpManager), _params[i].amount);
      receivedGlp += rewardRouter.mintAndStakeGlp(
        _params[i].token,
        _params[i].amount,
        _params[i].minAmountOutUSD,
        _params[i].minAmountOutGlp
      );
      // make sure the allowance is zero, in case of dust
      _token.safeDecreaseAllowance(_glpManager, _token.allowance(address(this), _glpManager));
      unchecked {
        ++i;
      }
    }
    if (_calculator.getHLPValueE30(true) < hlpValueBefore) {
      uint256 diffHlp = hlpValueBefore - _calculator.getHLPValueE30(true);
      // math opt.
      if ((diffHlp * BPS) >= (minTvlBPS * hlpValueBefore)) revert RebalanceHLPService_HlpTvlDropExceedMin();
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
