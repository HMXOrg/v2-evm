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
import { IReinvestNonHlpTokenStrategy } from "@hmx/strategies/interfaces/IReinvestNonHlpTokenStrategy.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

contract ReinvestNonHlpTokenStrategy is OwnableUpgradeable, IReinvestNonHlpTokenStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error ReinvestNonHlpTokenStrategy_OnlyWhitelist();
  error ReinvestNonHlpTokenStrategy_AddressIsZero();
  error ReinvestNonHlpTokenStrategy_AmountIsZero();
  error ReinvestNonHlpTokenStrategy_HlpTvlDropExceedMin();

  IERC20Upgradeable public sglp;

  ICalculator public calculator;

  IVaultStorage public vaultStorage;
  IGmxRewardRouterV2 public rewardRouter;
  IGmxGlpManager public glpManager;

  mapping(address => bool) public whitelistExecutors;

  address public treasury;

  uint16 public strategyBPS;
  uint16 public minTvlBPS;
  uint16 public constant BPS = 100_00;

  event SetTreasury(address _oldTreasury, address _newTreasury);
  event SetStrategyBPS(uint16 _oldStrategyBps, uint16 _newStrategyBps);
  event SetMinTvlBPS(uint16 _oldMinTvlBps, uint16 _newMinTvlBps);
  event SetWhitelistExecutor(address indexed _account, bool _active);

  struct ExecuteParams {
    address token;
    uint256 amount;
    uint256 minAmountOutMinUSD;
    uint256 minAmountOutMinGlp;
  }

  modifier onlyWhitelist() {
    // if not whitelist
    if (whitelistExecutors[msg.sender] == 1) {
      revert ReinvestNonHlpTokenStrategy_OnlyWhitelist();
    }
  }

  function initialize(
    address _sglp,
    address _rewardRouter,
    address _vaultStorage,
    address _glpManager,
    address _calculator,
    address _treasury,
    uint16 _strategyBPS,
    uint16 _minTvlBPS
  ) external initializer {
    __Ownable_init();
    sglp = IERC20Upgradeable(_sglp);
    rewardRouter = IGmxRewardRouterV2(_rewardRouter);
    vaultStorage = IVaultStorage(_vaultStorage);
    glpManager = IGmxGlpManager(_glpManager);
    calculator = ICalculator(_calculator);
    treasury = _treasury;
    strategyBPS = _strategyBPS;
    minTvlBPS = _minTvlBps;
  }

  function setWhiteListExecutor(address _executor, bool _active) external onlyOwner {
    if (_executor == address(0)) {
      revert ReinvestNonHlpTokenStrategy_AddressIsZero();
    }
    whitelistExecutors[_executor] = _active;
    emit SetWhitelistExecutor(_executor, _active);
  }

  function setStrategyBPS(uint16 _newStrategyBps) external onlyOwner {
    if (_newStrategyBps == 0) {
      revert ReinvestNonHlpTokenStrategy_AmountIsZero();
    }
    emit SetStrategyBPS(strategyBPS, _newStrategyBps);
    strategyBPS = _newStrategyBps;
  }

  function setMinTvlBPS(uint16 _oldMinTvlBps, uint16 _newMinTvlBps) external onlyOwner {
    if (_newMinTvlBps == 0) {
      revert ReinvestNonHlpTokenStrategy_AmountIsZero();
    }
    emit SetMinTvlBPS(_oldMinTvlBps, _newMinTvlBps);
    minTvlBPS = _newMinTvlBps;
  }

  function setTreasury(address _newTreasury) external onlyOwner {
    if (_newTreasury == address(0)) {
      revert ReinvestNonHlpTokenStrategy_AddressIsZero();
    }
    emit SetTreasury(treasury, _newTreasury);
    treasury = _newTreasury;
  }

  /// @dev when depositing ETH, just input the msg.value() and leave _token & _amount empty
  ///      NOTE If msg.value is not ZERO, will automatically reinvest in ETH with msg.value
  function execute(ExecuteParams[] _params) external onlyWhitelist {
    // SLOADS, gas opt.
    IERC20Upgradeable _sglp = sglp;
    IVaultStorage _vaultStorage = vaultStorage;
    IGmxRewardRouterV2 _rewardRouter = rewardRouter;
    ICalculator _calculator = calculator;

    uint256 hlpValueBefore = _calculator.getHLPValueE30(true);
    for (uint256 i = 0; i < _params.length; ) {
      if (_params[i].token == address(0) || _param[i].amount == 0) {
        continue;
      }
      IERC20Upgradeable _token = IERC20Upgradeable(_params[i].token);
      {
        // Reinvest to GLP
        uint256 strategyFee = (_params[i].amount * strategyBPS) / BPS;
        uint256 realizedAmount = _params[i].amount - strategyFee;
        _token.approve(address(glpManager), realizedAmount);
        _rewardRouter.mintAndStakeGlp(
          address(_token),
          realizedAmount,
          _params[i].minAmountOutUSD,
          _params[i].minAmountOutGlp
        );
      }
      // Settle
      uint256 sGlpBalance = _sglp.balanceOf(address(this));
      _token.safeTransfer(treasury, ststrategyFee);

      // Update accounting.
      _vaultStorage.pullToken(address(_sglp));
      _vaultStorage.addHLPLiquidity(address(_sglp), sGlpBalance);
      unchecked {
        ++i;
      }
    }
    uint256 hlpValueAfter = _calculator.getHLPValueE30(true);
    if (((hlpValueBefore - hlpValueAfter) * 1e8) < (minTvlBPS * hlpValueBefore)) {
      revert ReinvestNonHlpTokenStrategy_HlpTvlDropExceedMin();
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
