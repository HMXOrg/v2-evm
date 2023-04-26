// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IStakedGlpStrategy } from "@hmx/strategies/interfaces/IStakedGlpStrategy.sol";

contract StakedGlpStrategy is Owned, IStakedGlpStrategy {
  error StakedGlpStrategy_OnlyWhitelist();

  IERC20 public sglp;
  IERC20 public rewardToken;

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

  constructor(
    IERC20 _sglp,
    IGmxRewardRouterV2 _rewardRouter,
    IGmxRewardTracker _rewardTracker,
    IGmxGlpManager _glpManager,
    IOracleMiddleware _oracleMiddleware,
    IVaultStorage _vaultStorage,
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
