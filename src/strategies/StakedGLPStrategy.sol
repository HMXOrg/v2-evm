// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakedGlpStrategy is Owned, IStrategy {
  error StakedGlpStrategy_OnlyKeeper();

  IERC20 public sGlp;
  IERC20 public weth;
  IGmxRewardRouterV2 public gmxRewardRouter;
  IGmxRewardTracker public glpFeeTracker;

  IOracleMiddleware public oracleMiddleware;
  IVaultStorage public vaultStorage;

  address public keeper;

  address public treasury;
  uint16 public strategyBps;

  event SetKeeper(address _oldKeeper, address _newKeeper);
  event SetStrategyBps(uint16 _oldStrategyBps, uint16 _newStrategyBps);
  event SetTreasury(address _oldTreasury, address _newTreasury);

  constructor(
    IERC20 _sGlp,
    IGmxRewardRouterV2 _gmxRewardRouter,
    IGmxRewardTracker _glpFeeTracker,
    IOracleMiddleware _oracleMiddleware,
    IVaultStorage _vaultStorage,
    address _keeper,
    address _treasury,
    uint16 _strategyBps
  ) {
    sGlp = _sGlp;
    gmxRewardRouter = _gmxRewardRouter;
    glpFeeTracker = _glpFeeTracker;
    weth = IERC20(_glpFeeTracker.rewardToken());

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

  function execute() external {
    // Check.
    // 1. Only keeper can call this function.
    if (msg.sender != keeper) {
      revert StakedGlpStrategy_OnlyKeeper();
    }

    // 2. Build calldata.
    bytes memory _callData = abi.encodeWithSelector(IGmxRewardTracker.claim.selector, address(this));

    // 3. Cook
    uint256 wethBefore = weth.balanceOf(address(this));
    vaultStorage.cook(address(sGlp), address(glpFeeTracker), _callData);
    uint256 yields = weth.balanceOf(address(this)) - wethBefore;

    // 4. Deduct strategy fee.
    uint256 strategyFee = (yields * strategyBps) / 10000;

    // 5. Reinvest what left to GLP.
    gmxRewardRouter.mintAndStakeGlp(address(weth), weth.balanceOf(address(this)), 0, 0);

    // 6. Settle
    // SLOAD
    uint256 sGlpBalance = sGlp.balanceOf(address(this)) - strategyFee;
    sGlp.transfer(address(vaultStorage), sGlpBalance);
    weth.transfer(treasury, strategyFee);

    // 7. Update accounting.
    vaultStorage.pullToken(address(sGlp));
    vaultStorage.addPLPLiquidity(address(sGlp), sGlpBalance);
  }
}
