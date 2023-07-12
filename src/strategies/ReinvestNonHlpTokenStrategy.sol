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

  IERC20Upgradeable public sglp;
  ICalculator public calculator;

  IVaultStorage public vaultStorage;
  IGmxRewardRouterV2 public rewardRouter;
  IGmxGlpManager public glpManager;

  mapping(address => bool) public whitelistExecutors;

  uint16 public minTvlBPS;
  uint16 public constant BPS = 100_00;

  event SetMinTvlBPS(uint16 _oldMinTvlBps, uint16 _newMinTvlBps);
  event SetWhitelistExecutor(address indexed _account, bool _active);

  modifier onlyWhitelist() {
    // if not whitelist
    if (!whitelistExecutors[msg.sender]) {
      revert ReinvestNonHlpTokenStrategy_OnlyWhitelisted();
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
      revert ReinvestNonHlpTokenStrategy_AddressIsZero();
    }
    whitelistExecutors[_executor] = _active;
    emit SetWhitelistExecutor(_executor, _active);
  }

  function setMinTvlBPS(uint16 _newMinTvlBps) external onlyOwner {
    if (_newMinTvlBps == 0) {
      revert ReinvestNonHlpTokenStrategy_AmountIsZero();
    }
    emit SetMinTvlBPS(minTvlBPS, _newMinTvlBps);
    minTvlBPS = _newMinTvlBps;
  }

  function execute(ExecuteParams[] calldata _params) external onlyWhitelist returns (uint256 receivedGlp) {
    if (_params.length == 0) revert ReinvestNonHlpTokenStrategy_ParamsIsEmpty();
    // SLOADS, gas opt.
    ICalculator _calculator = calculator;

    uint256 hlpValueBefore = _calculator.getHLPValueE30(true);
    receivedGlp = 0;
    for (uint256 i = 0; i < _params.length; ) {
      // ignore if either value is zero
      if (_params[i].token == address(0) || _params[i].amount == 0) {
        continue;
      }
      // declare token
      IERC20Upgradeable _token = IERC20Upgradeable(_params[i].token);
      // cook
      receivedGlp += _cookAtVaultStorage(
        address(_token),
        _params[i].amount,
        _params[i].minAmountOutUSD,
        _params[i].minAmountOutGlp
      );
      unchecked {
        ++i;
      }
    }
    if (_calculator.getHLPValueE30(true) < hlpValueBefore) {
      uint256 diffHlp = hlpValueBefore - _calculator.getHLPValueE30(true);
      // math opt.
      if ((diffHlp * BPS) >= (minTvlBPS * hlpValueBefore)) revert ReinvestNonHlpTokenStrategy_HlpTvlDropExceedMin();
    }
  }

  function _cookAtVaultStorage(
    address _token,
    uint256 _amount,
    uint256 _minAmountOutUSD,
    uint256 _minAmountOutGlp
  ) internal returns (uint256 receivedGlp) {
    // declare struct to pass to vaultStorage.cook()
    IVaultStorage.CookParams[] memory cookParams = new IVaultStorage.CookParams[](2);
    IERC20Upgradeable _sglp = sglp;
    // SLOAD
    IVaultStorage _vaultStorage = vaultStorage;

    bytes memory _calldataApproveGlpManager = abi.encodeWithSelector(
      IERC20Upgradeable.approve.selector,
      address(glpManager),
      _amount
    );
    cookParams[0] = IVaultStorage.CookParams(_token, _token, _calldataApproveGlpManager);

    bytes memory _calldataMintAndStake = abi.encodeWithSelector(
      IGmxRewardRouterV2.mintAndStakeGlp.selector,
      _token,
      _amount,
      _minAmountOutUSD,
      _minAmountOutGlp
    );
    cookParams[1] = IVaultStorage.CookParams(_token, address(rewardRouter), _calldataMintAndStake);
    // cook! execute all func.
    bytes[] memory returnData = _vaultStorage.cook(cookParams);
    receivedGlp = abi.decode(returnData[cookParams.length - 1], (uint256));
    // update accounting
    _vaultStorage.pullToken(_token);
    _vaultStorage.removeHLPLiquidity(_token, _amount);
    _vaultStorage.pullToken(address(_sglp));
    _vaultStorage.addHLPLiquidity(address(_sglp), receivedGlp);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
