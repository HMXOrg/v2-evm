// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

contract StakedGlpStrategy is Owned, IStrategy {
  error StakedGlpStrategy_OnlyKeeper();

  IERC20 public sglp;
  IERC20 public rewardToken;

  IGmxRewardRouterV2 public rewardRouter;
  IGmxRewardTracker public rewardTracker;
  IGmxGlpManager public glpManager;

  IOracleMiddleware public oracleMiddleware;
  IVaultStorage public vaultStorage;

  address public keeper;

  address public treasury;
  uint16 public strategyBps;

  event SetKeeper(address _oldKeeper, address _newKeeper);
  event SetStrategyBps(uint16 _oldStrategyBps, uint16 _newStrategyBps);
  event SetTreasury(address _oldTreasury, address _newTreasury);

  /**
   * Modifiers
   */
  modifier onlyKepper() {
    if (msg.sender != keeper) {
      revert StakedGlpStrategy_OnlyKeeper();
    }
    _;
  }

  constructor(
    IERC20 _sglp,
    IGmxRewardRouterV2 _rewardRouter,
    IGmxRewardTracker _rewardTracker,
    IGmxGlpManager _glpManager,
    IOracleMiddleware _oracleMiddleware,
    IVaultStorage _vaultStorage,
    address _keeper,
    address _treasury,
    uint16 _strategyBps
  ) {
    sglp = _sglp;
    rewardRouter = _rewardRouter;
    rewardTracker = _rewardTracker;
    glpManager = _glpManager;
    rewardToken = IERC20(_rewardTracker.rewardToken());

    oracleMiddleware = _oracleMiddleware;
    vaultStorage = _vaultStorage;

    keeper = _keeper;

    treasury = _treasury;
    strategyBps = _strategyBps;
  }

  function setKeeper(address _newKeeper) external onlyOwner {
    emit SetKeeper(keeper, _newKeeper);
    keeper = _newKeeper;
  }

  function setStrategyBps(uint16 _newStrategyBps) external onlyOwner {
    emit SetStrategyBps(strategyBps, _newStrategyBps);
    strategyBps = _newStrategyBps;
  }

  function setTreasury(address _newTreasury) external onlyOwner {
    emit SetTreasury(treasury, _newTreasury);
    treasury = _newTreasury;
  }

  function execute() external onlyKepper {
    // 1. Build calldata.
    bytes memory _callData = abi.encodeWithSelector(IGmxRewardTracker.claim.selector, address(this));

    // 2. Cook
    uint256 rewardAmountBefore = rewardToken.balanceOf(address(this));
    vaultStorage.cook(address(sglp), address(rewardTracker), _callData);
    uint256 yields = rewardToken.balanceOf(address(this)) - rewardAmountBefore;

    // 3. Deduct strategy fee.
    uint256 strategyFee = (yields * strategyBps) / 10000;

    // 4. Reinvest what left to GLP.
    uint256 stakeAmount = yields - strategyFee;
    rewardToken.approve(address(glpManager), stakeAmount);
    rewardRouter.mintAndStakeGlp(address(rewardToken), stakeAmount, 0, 0);

    // 5. Settle
    // SLOAD
    uint256 sGlpBalance = sglp.balanceOf(address(this));

    sglp.transfer(address(vaultStorage), sGlpBalance);
    rewardToken.transfer(treasury, strategyFee);

    // 6. Update accounting.
    vaultStorage.pullToken(address(sglp));
    vaultStorage.addPLPLiquidity(address(sglp), sGlpBalance);
  }
}
