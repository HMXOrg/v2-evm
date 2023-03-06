// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/vendors/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/vendors/gmx/IGmxRewardTracker.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GlpStrategy is Owned, IStrategy {
  using AddressUtils for address;

  error GlpStrategy_OnlyKeeper();

  ERC20 public stkGlp;
  ERC20 public weth;
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
    ERC20 _stkGlp,
    IGmxRewardRouterV2 _gmxRewardRouter,
    IGmxRewardTracker _glpFeeTracker,
    IOracleMiddleware _oracleMiddleware,
    IVaultStorage _vaultStorage,
    address _keeper,
    address _treasury,
    uint16 _strategyBps
  ) {
    stkGlp = _stkGlp;
    gmxRewardRouter = _gmxRewardRouter;
    glpFeeTracker = _glpFeeTracker;
    weth = ERC20(_glpFeeTracker.rewardToken());

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
      revert GlpStrategy_OnlyKeeper();
    }

    // 2. Build calldata.
    bytes memory _callData = abi.encodeWithSelector(IGmxRewardTracker.claim.selector, address(this));

    // 3. Cook
    uint256 wethBefore = weth.balanceOf(address(this));
    vaultStorage.cook(address(stkGlp), address(glpFeeTracker), _callData);
    uint256 yields = weth.balanceOf(address(this)) - wethBefore;

    // 4. Deduct strategy fee.
    uint256 strategyFee = (yields * strategyBps) / 10000;

    // 5. Reinvest what left to GLP.
    // Load GLP price
    gmxRewardRouter.mintAndStakeGlp(address(weth), weth.balanceOf(address(this)), 0, 0);

    // 6. Settle
    // SLOAD
    uint256 stkGlpBalance = stkGlp.balanceOf(address(this));
    stkGlp.transfer(address(vaultStorage), stkGlp.balanceOf(address(this)));
    weth.transfer(treasury, strategyFee);

    // 7. Update accounting.
    vaultStorage.pullToken(address(stkGlp));
    vaultStorage.addPLPLiquidity(address(stkGlp), stkGlpBalance);
  }
}
