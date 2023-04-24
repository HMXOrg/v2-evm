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
import { console } from "forge-std/console.sol";

//FIXME use Istrategy back ?
contract UnstakedGlpStrategy is Owned {
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

    strategyBps = _strategyBps;
  }

  function setKeeper(address _newKeeper) external onlyOwner {
    emit SetKeeper(keeper, _newKeeper);
    keeper = _newKeeper;
  }

  function execute(address _tokenOut, uint256 _amount) external onlyKepper returns (uint256 _amountOut) {
    // 1. transfer sglp token to this address
    vaultStorage.pushToken(address(sglp), address(this), _amount);
    // 2. Build calldata.
    bytes memory _callData = abi.encodeWithSelector(
      IGmxRewardRouterV2.unstakeAndRedeemGlp.selector,
      _tokenOut,
      _amount,
      0,
      address(this)
    );

    bytes memory _result = vaultStorage.cook(address(sglp), address(rewardRouter), _callData);
    console.log("cook Result");
    console.logBytes(_result);

    uint256 aaaa = abi.decode(_result, (uint256));
    console.log("aaa", aaaa);

    // 3. transfer all to vault
    IERC20(_tokenOut).transfer(address(vaultStorage), _amountOut);
    vaultStorage.pullToken(_tokenOut);

    //TODO dust should be reinvest

    return 0;
  }
}
