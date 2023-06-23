// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.
//   _   _ __  ____  __
//  | | | |  \/  \ \/ /
//  | |_| | |\/| |\  /
//  |  _  | |  | |/  \
//  |_| |_|_|  |_/_/\_\
//

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IStakedGlpStrategy } from "@hmx/strategies/interfaces/IStakedGlpStrategy.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract StakedGlpStrategy is OwnableUpgradeable, IStakedGlpStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error StakedGlpStrategy_OnlyWhitelist();

  IERC20Upgradeable public sglp;
  IERC20Upgradeable public rewardToken;

  IGmxRewardRouterV2 public rewardRouter;
  IGmxRewardTracker public rewardTracker;
  IGmxGlpManager public glpManager;

  IOracleMiddleware public oracleMiddleware;
  IVaultStorage public vaultStorage;

  mapping(address => bool) public whitelistExecutors;

  address public treasury;
  uint16 public strategyBps;

  event SetStrategyBps(uint16 _oldStrategyBps, uint16 _newStrategyBps);
  event SetTreasury(address _oldTreasury, address _newTreasury);
  event SetWhitelistExecutor(address indexed _account, bool _active);

  /**
   * Modifiers
   */
  modifier onlyWhitelist() {
    if (!whitelistExecutors[msg.sender]) {
      revert StakedGlpStrategy_OnlyWhitelist();
    }
    _;
  }

  function initialize(
    IERC20Upgradeable _sglp,
    IStakedGlpStrategy.StakedGlpStrategyConfig memory _stakedGlpStrategyConfig,
    address _treasury,
    uint16 _strategyBps
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    sglp = _sglp;
    rewardRouter = _stakedGlpStrategyConfig.rewardRouter;
    rewardTracker = _stakedGlpStrategyConfig.rewardTracker;
    glpManager = _stakedGlpStrategyConfig.glpManager;
    rewardToken = IERC20Upgradeable(_stakedGlpStrategyConfig.rewardTracker.rewardToken());

    oracleMiddleware = _stakedGlpStrategyConfig.oracleMiddleware;
    vaultStorage = _stakedGlpStrategyConfig.vaultStorage;

    treasury = _treasury;
    strategyBps = _strategyBps;
  }

  function setWhiteListExecutor(address _executor, bool _active) external onlyOwner {
    whitelistExecutors[_executor] = _active;
    emit SetWhitelistExecutor(_executor, _active);
  }

  function setStrategyBps(uint16 _newStrategyBps) external onlyOwner {
    emit SetStrategyBps(strategyBps, _newStrategyBps);
    strategyBps = _newStrategyBps;
  }

  function setTreasury(address _newTreasury) external onlyOwner {
    emit SetTreasury(treasury, _newTreasury);
    treasury = _newTreasury;
  }

  function execute() external onlyWhitelist {
    // SLOADs
    IERC20Upgradeable _rewardToken = rewardToken;
    IERC20Upgradeable _sglp = sglp;
    IVaultStorage _vaultStorage = vaultStorage;

    // 1. Build calldata.
    bytes memory _callData = abi.encodeWithSelector(IGmxRewardTracker.claim.selector, address(this));

    // 2. Cook
    uint256 rewardAmountBefore = _rewardToken.balanceOf(address(this));
    _vaultStorage.cook(address(_sglp), address(rewardTracker), _callData);
    uint256 yields = _rewardToken.balanceOf(address(this)) - rewardAmountBefore;

    // 3. Deduct strategy fee.
    uint256 strategyFee = (yields * strategyBps) / 10000;

    // 4. Reinvest what left to GLP.
    uint256 stakeAmount = yields - strategyFee;
    _rewardToken.approve(address(glpManager), stakeAmount);
    rewardRouter.mintAndStakeGlp(address(_rewardToken), stakeAmount, 0, 0);

    // 5. Settle
    // SLOAD
    uint256 sGlpBalance = _sglp.balanceOf(address(this));

    _sglp.safeTransfer(address(_vaultStorage), sGlpBalance);
    _rewardToken.safeTransfer(treasury, strategyFee);

    // 6. Update accounting.
    _vaultStorage.pullToken(address(_sglp));
    _vaultStorage.addHLPLiquidity(address(_sglp), sGlpBalance);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
