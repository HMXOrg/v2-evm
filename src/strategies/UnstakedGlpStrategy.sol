// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { console } from "forge-std/console.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";

import { IUnstakedGlpStrategy } from "@hmx/strategies/interfaces/IUnstakedGlpStrategy.sol";

contract UnstakedGlpStrategy is Owned, IUnstakedGlpStrategy {
  error UnstakedGlpStrategy_OnlyWhitelisted();

  IERC20 public sglp;

  IGmxRewardRouterV2 public rewardRouter;
  IVaultStorage public vaultStorage;

  mapping(address => bool) public whitelistExecutors;

  event SetWhitelistExecutor(address indexed _account, bool _active);

  /**
   * Modifiers
   */
  modifier onlyWhitelist() {
    if (!whitelistExecutors[msg.sender]) {
      revert UnstakedGlpStrategy_OnlyWhitelisted();
    }
    _;
  }

  constructor(IERC20 _sglp, IGmxRewardRouterV2 _rewardRouter, IVaultStorage _vaultStorage) {
    sglp = _sglp;
    rewardRouter = _rewardRouter;
    vaultStorage = _vaultStorage;
  }

  function setWhiteListExecutor(address _executor, bool _active) external onlyOwner {
    whitelistExecutors[_executor] = _active;
    emit SetWhitelistExecutor(_executor, _active);
  }

  function execute(address _tokenOut, uint256 _amount) external onlyWhitelist returns (uint256 _amountOut) {
    // 1. Build calldata.
    bytes memory _callData = abi.encodeWithSelector(
      IGmxRewardRouterV2.unstakeAndRedeemGlp.selector,
      _tokenOut,
      _amount,
      0,
      address(this)
    );

    // 2. Unstake sglp from GMX
    bytes memory _cookResult = vaultStorage.cook(address(sglp), address(rewardRouter), _callData);
    _amountOut = abi.decode(_cookResult, (uint256));

    // 3. Transfer token to vaultStorage
    IERC20(_tokenOut).transfer(address(vaultStorage), _amountOut);
    vaultStorage.pullToken(_tokenOut);

    return _amountOut;
  }
}
