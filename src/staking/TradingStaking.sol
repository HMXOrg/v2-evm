// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRewarder } from "./interfaces/IRewarder.sol";

contract TradingStaking is Owned, ReentrancyGuard {
  using SafeCast for int256;
  using SafeCast for uint256;
  using SafeERC20 for IERC20;

  error TradingStaking_DuplicatePool();
  error TradingStaking_Forbidden();
  error TradingStaking_InvalidArguments();

  struct UserInfo {
    uint256 amount;
    int256 rewardDebt;
  }

  struct PoolInfo {
    uint128 accRewardTokenPerShare;
    uint64 lastRewardTime;
    uint64 allocPoint;
  }

  IERC20 public rewardToken;
  PoolInfo[] public poolInfo;
  uint256[] public marketIndices;
  mapping(uint256 => uint256) public stakingSizeByMarketIndex;
  IRewarder[] public rewarder;
  mapping(uint256 => bool) public isAcceptedMarketIndex;
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  uint256 public totalAllocPoint;
  uint256 public rewardTokenPerSecond;
  uint256 private constant ACC_REWARD_TOKEN_PRECISION = 1e20;
  uint256 public maxRewardTokenPerSecond;
  address public whitelistedCaller;

  event LogDeposit(address indexed caller, address indexed user, uint256 indexed pid, uint256 amount);
  event LogWithdraw(address indexed caller, address indexed user, uint256 indexed pid, uint256 amount);
  event LogEmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event LogHarvest(address indexed user, uint256 indexed pid, uint256 amount);
  event LogAddPool(uint256 indexed pid, uint256 allocPoint, uint256 indexed marketIndex, IRewarder indexed rewarder);
  event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
  event LogUpdatePool(
    uint256 indexed pid,
    uint64 lastRewardTime,
    uint256 stakedBalance,
    uint256 accRewardTokenPerShare
  );
  event LogRewardTokenPerSecond(uint256 rewardTokenPerSecond);
  event LogSetMaxRewardTokenPerSecond(uint256 maxRewardTokenPerSecond);

  /// @param _rewardToken The rewardToken token contract address.
  constructor(address _rewardToken, uint256 _maxRewardTokenPerSecond) {
    rewardToken = IERC20(_rewardToken);
    maxRewardTokenPerSecond = _maxRewardTokenPerSecond;
  }

  modifier onlyWhitelistedCaller() {
    if (msg.sender != whitelistedCaller) revert TradingStaking_Forbidden();
    _;
  }

  /// @notice Returns the number of pools.
  function poolLength() public view returns (uint256 pools) {
    pools = poolInfo.length;
  }

  /// @notice Add a new staking token pool. Can only be called by the owner.
  /// @param _allocPoint AP of the new pool.
  /// @param _marketIndex Address of the staking token.
  /// @param _rewarder Address of the rewarder delegate.
  /// @param _withUpdate If true, do mass update pools.
  function addPool(
    uint256 _allocPoint,
    uint256 _marketIndex,
    IRewarder _rewarder,
    bool _withUpdate
  ) external onlyOwner {
    if (isAcceptedMarketIndex[_marketIndex]) revert TradingStaking_DuplicatePool();

    if (_withUpdate) massUpdatePools();

    totalAllocPoint = totalAllocPoint + _allocPoint;
    marketIndices.push(_marketIndex);
    rewarder.push(_rewarder);
    isAcceptedMarketIndex[_marketIndex] = true;

    if (address(_rewarder) != address(0)) {
      // Sanity check that the rewarder is a valid IRewarder.
      _rewarder.name();
    }

    poolInfo.push(
      PoolInfo({
        allocPoint: _allocPoint.toUint64(),
        lastRewardTime: block.timestamp.toUint64(),
        accRewardTokenPerShare: 0
      })
    );
    emit LogAddPool(marketIndices.length - 1, _allocPoint, _marketIndex, _rewarder);
  }

  /// @notice Update the given pool's rewardToken allocation point and `IRewarder` contract.
  /// @dev Can only be called by the owner.
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @param _allocPoint New AP of the pool.
  /// @param _rewarder Address of the rewarder delegate.
  /// @param _overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
  /// @param _withUpdate If true, do mass update pools
  function setPool(
    uint256 _pid,
    uint256 _allocPoint,
    IRewarder _rewarder,
    bool _overwrite,
    bool _withUpdate
  ) external onlyOwner {
    if (_withUpdate) massUpdatePools();

    totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
    poolInfo[_pid].allocPoint = _allocPoint.toUint64();
    if (_overwrite) {
      // Sanity check that the rewarder is a valid IRewarder.
      _rewarder.name();
      rewarder[_pid] = _rewarder;
    }
    emit LogSetPool(_pid, _allocPoint, _overwrite ? _rewarder : rewarder[_pid], _overwrite);
  }

  /// @notice Sets the rewardToken per second to be distributed. Can only be called by the owner.
  /// @param _rewardTokenPerSecond The amount of rewardToken to be distributed per second.
  /// @param _withUpdate If true, do mass update pools
  function setrewardTokenPerSecond(uint256 _rewardTokenPerSecond, bool _withUpdate) external onlyOwner {
    if (_rewardTokenPerSecond > maxRewardTokenPerSecond) revert TradingStaking_InvalidArguments();

    if (_withUpdate) massUpdatePools();
    rewardTokenPerSecond = _rewardTokenPerSecond;
    emit LogRewardTokenPerSecond(_rewardTokenPerSecond);
  }

  /// @notice View function to see pending rewardToken on frontend.
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @param _user Address of a user.
  /// @return pending rewardToken reward for a given user.
  function pendingRewardToken(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo memory pool = poolInfo[_pid];
    UserInfo memory user = userInfo[_pid][_user];
    uint256 accRewardTokenPerShare = pool.accRewardTokenPerShare;
    uint256 stakedBalance = stakingSizeByMarketIndex[marketIndices[_pid]];
    if (block.timestamp > pool.lastRewardTime && stakedBalance != 0) {
      uint256 timePast = block.timestamp - pool.lastRewardTime;
      uint256 rewardTokenReward = (timePast * rewardTokenPerSecond * pool.allocPoint) / totalAllocPoint;
      accRewardTokenPerShare =
        accRewardTokenPerShare +
        ((rewardTokenReward * ACC_REWARD_TOKEN_PRECISION) / stakedBalance);
    }

    return
      (((user.amount * accRewardTokenPerShare) / ACC_REWARD_TOKEN_PRECISION).toInt256() - user.rewardDebt).toUint256();
  }

  /// @notice Perform actual update pool.
  /// @param pid The index of the pool. See `poolInfo`.
  /// @return pool Returns the pool that was updated.
  function _updatePool(uint256 pid) internal returns (PoolInfo memory) {
    PoolInfo memory pool = poolInfo[pid];
    if (block.timestamp > pool.lastRewardTime) {
      uint256 stakedBalance = stakingSizeByMarketIndex[marketIndices[pid]];
      if (stakedBalance > 0) {
        uint256 timePast = block.timestamp - pool.lastRewardTime;
        uint256 rewardTokenReward = (timePast * rewardTokenPerSecond * pool.allocPoint) / totalAllocPoint;
        pool.accRewardTokenPerShare =
          pool.accRewardTokenPerShare +
          ((rewardTokenReward * ACC_REWARD_TOKEN_PRECISION) / stakedBalance).toUint128();
      }
      pool.lastRewardTime = block.timestamp.toUint64();
      poolInfo[pid] = pool;
      emit LogUpdatePool(pid, pool.lastRewardTime, stakedBalance, pool.accRewardTokenPerShare);
    }
    return pool;
  }

  /// @notice Update reward variables of the given pool.
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @return pool Returns the pool that was updated.
  function updatePool(uint256 _pid) external nonReentrant returns (PoolInfo memory) {
    return _updatePool(_pid);
  }

  /// @notice Update reward variables for a given pools.
  function updatePools(uint256[] calldata _pids) external nonReentrant {
    uint256 len = _pids.length;
    for (uint256 i = 0; i < len; i++) {
      _updatePool(_pids[i]);
    }
  }

  /// @notice Update reward variables for all pools.
  function massUpdatePools() public nonReentrant {
    uint256 len = poolLength();
    for (uint256 i = 0; i < len; ++i) {
      _updatePool(i);
    }
  }

  /// @notice Deposit tokens to TradingStaking for rewardToken allocation.
  /// @param _for The beneficary address of the deposit.
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @param _amount amount to deposit.
  function deposit(address _for, uint256 _pid, uint256 _amount) external onlyWhitelistedCaller nonReentrant {
    PoolInfo memory pool = _updatePool(_pid);
    UserInfo storage user = userInfo[_pid][_for];

    // Effects
    user.amount = user.amount + _amount;
    user.rewardDebt =
      user.rewardDebt +
      ((_amount * pool.accRewardTokenPerShare) / ACC_REWARD_TOKEN_PRECISION).toInt256();

    // Update total staked position size of that market index
    stakingSizeByMarketIndex[marketIndices[_pid]] += _amount;

    // Interactions
    IRewarder _rewarder = rewarder[_pid];
    if (address(_rewarder) != address(0)) {
      _rewarder.onDeposit(_pid, _for, 0, user.amount);
    }

    emit LogDeposit(msg.sender, _for, _pid, _amount);
  }

  /// @notice Withdraw tokens from TradingStaking.
  /// @param _for Withdraw for who?
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @param _amount Staking token amount to withdraw.
  function withdraw(address _for, uint256 _pid, uint256 _amount) external onlyWhitelistedCaller nonReentrant {
    PoolInfo memory pool = _updatePool(_pid);
    UserInfo storage user = userInfo[_pid][_for];

    // Effects
    user.rewardDebt =
      user.rewardDebt -
      (((_amount * pool.accRewardTokenPerShare) / ACC_REWARD_TOKEN_PRECISION)).toInt256();
    user.amount = user.amount - _amount;

    // Update total staked position size of that market index
    stakingSizeByMarketIndex[marketIndices[_pid]] -= _amount;

    // Interactions
    IRewarder _rewarder = rewarder[_pid];
    if (address(_rewarder) != address(0)) {
      _rewarder.onWithdraw(_pid, _for, 0, user.amount);
    }

    emit LogWithdraw(msg.sender, _for, _pid, _amount);
  }

  /// @notice Harvest rewardToken rewards
  /// @param _pid The index of the pool. See `poolInfo`.
  function harvest(uint256 _pid) external nonReentrant {
    PoolInfo memory pool = _updatePool(_pid);
    UserInfo storage user = userInfo[_pid][msg.sender];

    int256 accumulatedrewardToken = ((user.amount * pool.accRewardTokenPerShare) / ACC_REWARD_TOKEN_PRECISION)
      .toInt256();
    uint256 _pendingrewardToken = (accumulatedrewardToken - user.rewardDebt).toUint256();

    // Effects
    user.rewardDebt = accumulatedrewardToken;

    // Interactions
    if (_pendingrewardToken != 0) {
      rewardToken.safeTransfer(msg.sender, _pendingrewardToken);
    }

    IRewarder _rewarder = rewarder[_pid];
    if (address(_rewarder) != address(0)) {
      _rewarder.onHarvest(_pid, msg.sender, 0);
    }

    emit LogHarvest(msg.sender, _pid, _pendingrewardToken);
  }

  /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
  /// @param _pid The index of the pool. See `poolInfo`.
  function emergencyWithdraw(uint256 _pid, address _for) external onlyWhitelistedCaller nonReentrant {
    PoolInfo storage _pool = poolInfo[_pid];
    UserInfo storage _user = userInfo[_pid][_for];

    uint256 _amount = _user.amount;
    _user.amount = 0;
    _user.rewardDebt = 0;

    stakingSizeByMarketIndex[marketIndices[_pid]] -= _amount;

    IRewarder _rewarder = rewarder[_pid];
    if (address(_rewarder) != address(0)) {
      _rewarder.onWithdraw(_pid, _for, 0, 0);
    }

    emit LogEmergencyWithdraw(_for, _pid, _amount);
  }

  /// @notice Set max reward per second
  /// @param _maxRewardTokenPerSecond The max reward per second
  function setMaxrewardTokenPerSecond(uint256 _maxRewardTokenPerSecond) external onlyOwner {
    if (_maxRewardTokenPerSecond <= rewardTokenPerSecond) revert TradingStaking_InvalidArguments();
    maxRewardTokenPerSecond = _maxRewardTokenPerSecond;
    emit LogSetMaxRewardTokenPerSecond(_maxRewardTokenPerSecond);
  }
}
