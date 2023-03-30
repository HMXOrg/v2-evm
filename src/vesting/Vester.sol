// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { IVester } from "./interfaces/IVester.sol";

contract Vester is ReentrancyGuardUpgradeable, IVester {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 private constant YEAR = 365 days;

  /**
   * Events
   */
  event Vest(
    address indexed owner,
    uint256 indexed itemIndex,
    uint256 amount,
    uint256 startTime,
    uint256 endTime,
    uint256 penaltyAmount
  );
  event Claim(address indexed owner, uint256 indexed itemIndex, uint256 vestedAmount, uint256 unusedAmount);
  event Abort(address indexed owner, uint256 indexed itemIndex, uint256 returnAmount);

  /**
   * States
   */
  address public esHMX;
  address public hmx;

  address public vestedEsHmxDestination;
  address public unusedEsHmxDestination;

  Item[] public override items;

  function initialize(
    address esHMXAddress,
    address hmxAddress,
    address vestedEsHmxDestinationAddress,
    address unusedEsHmxDestinationAddress
  ) external initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    esHMX = esHMXAddress;
    hmx = hmxAddress;
    vestedEsHmxDestination = vestedEsHmxDestinationAddress;
    unusedEsHmxDestination = unusedEsHmxDestinationAddress;
  }

  function vestFor(address account, uint256 amount, uint256 duration) external nonReentrant {
    if (account == address(0) || account == address(this)) revert IVester_InvalidAddress();
    if (amount == 0) revert IVester_BadArgument();
    if (duration > YEAR) revert IVester_ExceedMaxDuration();

    Item memory item = Item({
      owner: account,
      amount: amount,
      startTime: block.timestamp,
      endTime: block.timestamp + duration,
      hasAborted: false,
      hasClaimed: false,
      lastClaimTime: block.timestamp,
      totalUnlockedAmount: getUnlockAmount(amount, duration)
    });

    items.push(item);

    uint256 penaltyAmount = amount - item.totalUnlockedAmount;

    IERC20Upgradeable(esHMX).safeTransferFrom(msg.sender, address(this), amount);

    if (penaltyAmount > 0) {
      IERC20Upgradeable(esHMX).safeTransfer(unusedEsHmxDestination, penaltyAmount);
    }

    emit Vest(item.owner, items.length - 1, amount, item.startTime, item.endTime, penaltyAmount);
  }

  function claimFor(address account, uint256 itemIndex) external nonReentrant {
    _claimFor(account, itemIndex);
  }

  function claimFor(address account, uint256[] memory itemIndexes) external nonReentrant {
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      _claimFor(account, itemIndexes[i]);
    }
  }

  function _claimFor(address account, uint256 itemIndex) internal {
    Item storage item = items[itemIndex];

    if (item.owner != account) revert IVester_Unauthorized();
    if (item.hasClaimed) revert IVester_Claimed();
    if (item.hasAborted) revert IVester_Aborted();

    uint256 elapsedDuration = block.timestamp < item.endTime
      ? block.timestamp - item.lastClaimTime
      : item.endTime - item.lastClaimTime;
    uint256 claimable = getUnlockAmount(item.amount, elapsedDuration);

    // If vest has ended, then mark this as claimed.
    if (block.timestamp > item.endTime) items[itemIndex].hasClaimed = true;

    items[itemIndex].lastClaimTime = block.timestamp;

    IERC20Upgradeable(hmx).safeTransfer(account, claimable);

    IERC20Upgradeable(esHMX).safeTransfer(vestedEsHmxDestination, claimable);

    emit Claim(item.owner, itemIndex, claimable, item.amount - claimable);
  }

  function abort(uint256 itemIndex) external nonReentrant {
    Item storage item = items[itemIndex];
    if (msg.sender != item.owner) revert IVester_Unauthorized();
    if (block.timestamp > item.endTime) revert IVester_HasCompleted();
    if (item.hasClaimed) revert IVester_Claimed();
    if (item.hasAborted) revert IVester_Aborted();

    _claimFor(item.owner, itemIndex);

    uint256 elapsedDurationSinceStart = block.timestamp - item.startTime;
    uint256 amountUsed = getUnlockAmount(item.amount, elapsedDurationSinceStart);
    uint256 returnAmount = item.totalUnlockedAmount - amountUsed;

    items[itemIndex].hasAborted = true;

    IERC20Upgradeable(esHMX).safeTransfer(msg.sender, returnAmount);

    emit Abort(msg.sender, itemIndex, returnAmount);
  }

  function getUnlockAmount(uint256 amount, uint256 duration) public pure returns (uint256) {
    // The total unlock amount if the user wait until the end of the vest duration
    // totalUnlockAmount = (amount * vestDuration) / YEAR
    // Return the adjusted unlock amount based on the elapsed duration
    // pendingUnlockAmount = (totalUnlockAmount * elapsedDuration) / vestDuration
    // OR
    // pendingUnlockAmount = ((amount * vestDuration) / YEAR * elapsedDuration) / vestDuration
    //                     = (amount * vestDuration * elapsedDuration) / YEAR / vestDuration
    //                     = (amount * elapsedDuration) / YEAR
    return (amount * duration) / YEAR;
  }

  function nextItemId() external view returns (uint256) {
    return items.length;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
