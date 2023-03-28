// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

contract Vester is ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 private constant YEAR = 365 days;

  // ---------------------
  //       Events
  // ---------------------

  event Vest(
    address indexed owner,
    uint256 indexed itemIndex,
    uint256 amount,
    uint256 startTime,
    uint256 endTime,
    uint256 penaltyAmount
  );

  event Claim(address indexed owner, uint256 indexed itemIndex, uint256 vestedAmount, uint256 unusedAmount);

  event Cancel(address indexed owner, uint256 indexed itemIndex, uint256 returnAmount);

  // ---------------------
  //       Errors
  // ---------------------
  error BadArgument();
  error ExceedMaxDuration();
  error Unauthorized();
  error Claimed();
  error Aborted();
  error HasNotCompleted();
  error HasCompleted();

  // ---------------------
  //       Structs
  // ---------------------
  struct Item {
    address owner;
    bool hasClaimed;
    bool hasAborted;
    uint256 amount;
    uint256 startTime;
    uint256 endTime;
    uint256 lastClaimTime;
    uint256 totalUnlockedAmount;
  }

  // ---------------------
  //       States
  // ---------------------
  address public esP88;
  address public p88;

  address public vestedEsp88Destination;
  address public unusedEsp88Destination;

  Item[] public items;

  function initialize(
    address esP88Address,
    address p88Address,
    address vestedEsp88DestinationAddress,
    address unusedEsp88DestinationAddress
  ) external initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    esP88 = esP88Address;
    p88 = p88Address;
    vestedEsp88Destination = vestedEsp88DestinationAddress;
    unusedEsp88Destination = unusedEsp88DestinationAddress;
  }

  function vestFor(address account, uint256 amount, uint256 duration) external nonReentrant {
    if (amount == 0) revert BadArgument();
    if (duration > YEAR) revert ExceedMaxDuration();

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

    IERC20Upgradeable(esP88).safeTransferFrom(msg.sender, address(this), amount);

    if (penaltyAmount > 0) {
      IERC20Upgradeable(esP88).safeTransfer(unusedEsp88Destination, penaltyAmount);
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

    if (item.owner != account) revert Unauthorized();
    if (item.hasClaimed) revert Claimed();
    if (item.hasAborted) revert Aborted();

    uint256 elapsedDuration = block.timestamp < item.endTime
      ? block.timestamp - item.lastClaimTime
      : item.endTime - item.lastClaimTime;
    uint256 claimable = getUnlockAmount(item.amount, elapsedDuration);

    // If vest has ended, then mark this as claimed.
    if (block.timestamp > item.endTime) item.hasClaimed = true;

    item.lastClaimTime = block.timestamp;

    IERC20Upgradeable(p88).safeTransfer(account, claimable);

    IERC20Upgradeable(esP88).safeTransfer(vestedEsp88Destination, claimable);

    emit Claim(item.owner, itemIndex, claimable, item.amount - claimable);
  }

  function abort(uint256 itemIndex) external nonReentrant {
    Item storage item = items[itemIndex];
    if (msg.sender != item.owner) revert Unauthorized();
    if (block.timestamp > item.endTime) revert HasCompleted();

    _claimFor(item.owner, itemIndex);

    uint256 elapsedDurationSinceStart = block.timestamp - item.startTime;
    uint256 amountUsed = getUnlockAmount(item.amount, elapsedDurationSinceStart);
    uint256 returnAmount = item.totalUnlockedAmount - amountUsed;

    item.hasAborted = true;

    IERC20Upgradeable(esP88).safeTransfer(msg.sender, returnAmount);

    emit Cancel(msg.sender, itemIndex, returnAmount);
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
