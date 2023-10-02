// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IRewarder } from "./interfaces/IRewarder.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";

contract TradingStaking is OwnableUpgradeable, ITradingStaking {
  /**
   * Errors
   */
  error TradingStaking_UnknownMarketIndex();
  error TradingStaking_InsufficientTokenAmount();
  error TradingStaking_NotRewarder();
  error TradingStaking_NotCompounder();
  error TradingStaking_Forbidden();

  /**
   * Events
   */
  event LogDeposit(address indexed caller, address indexed user, uint256 marketIndex, uint256 amount);
  event LogWithdraw(address indexed caller, uint256 marketIndex, uint256 amount);
  event LogAddStakingToken(uint256 newMarketIndex, address[] newRewarders);
  event LogAddRewarder(address newRewarder, uint256[] newTokens);
  event LogSetCompounder(address oldCompounder, address newCompounder);
  event LogSetWhitelistedCaller(address oldAddress, address newAddress);

  /**
   * States
   */
  mapping(uint256 => mapping(address => uint256)) public userTokenAmount;
  mapping(uint256 => uint256) public totalShares;
  mapping(address => bool) public isRewarder;
  mapping(uint256 => bool) public isMarketIndex;
  mapping(uint256 => address[]) public marketIndexRewarders;
  mapping(address => uint256[]) public rewarderMarketIndex;
  address public compounder;
  address public whitelistedCaller;

  /**
   * Modifiers
   */
  modifier onlyWhitelistedCaller() {
    if (msg.sender != whitelistedCaller) revert TradingStaking_Forbidden();
    _;
  }

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();
  }

  /// @dev Add a new Market Pool for multiple rewarding addresses. Only the owner of the contract can call this function.
  /// @param _newMarketIndex The index of the new market pool to be added
  /// @param _newRewarders An array of addresses to be added as rewarder to the new market pool
  function addPool(uint256 _newMarketIndex, address[] memory _newRewarders) external onlyOwner {
    //Obtaining the length of the new rewarder addresses array to process each one of them on the loop
    uint256 length = _newRewarders.length;

    //Executing an iteration over each of the rewarders passed as parameter to add them to the pool
    for (uint256 i; i < length; ) {
      //Updating the pool data for this rewarder address and the new markey index provided
      _updatePool(_newMarketIndex, _newRewarders[i]);

      //Incrementing iterator inside 'unchecked' block
      unchecked {
        ++i;
      }
    }

    //Logging the addition of the new staking token to the system
    emit LogAddStakingToken(_newMarketIndex, _newRewarders);
  }

  /// @dev Add a new rewarder to the pool and sets a market index.
  /// @param _newRewarder The address for the new rewarder.
  /// @param _newMarketIndex The array of new market indexes to be set for this rewarder.
  /// Emits a {LogAddRewarder} event indicating that a new rewarder was added.
  function addRewarder(address _newRewarder, uint256[] memory _newMarketIndex) external onlyOwner {
    //Obtaining the length of the market index array to process each one of them on the loop
    uint256 length = _newMarketIndex.length;
    //Iterating over provided market indexes to set new rewarder
    for (uint256 i; i < length; ) {
      //Updating the pool data for this rewarder and the corresponding market index provided
      _updatePool(_newMarketIndex[i], _newRewarder);

      //Emitting LogAddRewarder event
      emit LogAddRewarder(_newRewarder, _newMarketIndex);

      //Incrementing iterator inside 'unchecked' block
      unchecked {
        ++i;
      }
    }
  }

  /// @dev Removes a rewarder address from a market index by its corresponding index. The function deletes the removed rewarder from the
  /// marketIndexRewarders list.
  /// @param _removeRewarderIndex The index of the rewarder address to be removed from the market index
  /// @param _marketIndex The index of the market whose mapped rewarder will be removed
  function removeRewarderForMarketIndexByIndex(uint256 _removeRewarderIndex, uint256 _marketIndex) external onlyOwner {
    uint256 _marketIndexLength = marketIndexRewarders[_marketIndex].length;
    address removedRewarder = marketIndexRewarders[_marketIndex][_removeRewarderIndex];
    marketIndexRewarders[_marketIndex][_removeRewarderIndex] = marketIndexRewarders[_marketIndex][
      _marketIndexLength - 1
    ];
    marketIndexRewarders[_marketIndex].pop();

    uint256 rewarderLength = rewarderMarketIndex[removedRewarder].length;
    for (uint256 i; i < rewarderLength; ) {
      if (rewarderMarketIndex[removedRewarder][i] == _marketIndex) {
        rewarderMarketIndex[removedRewarder][i] = rewarderMarketIndex[removedRewarder][rewarderLength - 1];
        rewarderMarketIndex[removedRewarder].pop();
        if (rewarderLength == 1) isRewarder[removedRewarder] = false;

        break;
      }
      unchecked {
        ++i;
      }
    }
  }

  /// @dev Internal function to update a staking pool for a new rewarder and market index
  /// If the provided newRewarder address is not already in marketIndexRewarders for _marketIndex, it will be added
  /// Additionally, if the _marketIndex is not already associated with the provided newRewarder, it will be pushed into rewarderMarketIndex
  /// Also makes sure the _marketIndex is marked as existing by setting isMarketIndex to true
  /// Finally, sets the value of isRewarder[newRewarder] to true
  /// @param _marketIndex uint256 Market index to add staking data to
  /// @param _newRewarder address Address of new rewarder account to add to the specified market index's rewarders
  function _updatePool(uint256 _marketIndex, address _newRewarder) internal {
    if (!isDuplicatedRewarder(_marketIndex, _newRewarder)) marketIndexRewarders[_marketIndex].push(_newRewarder);
    if (!isDuplicatedStakingToken(_marketIndex, _newRewarder)) rewarderMarketIndex[_newRewarder].push(_marketIndex);

    isMarketIndex[_marketIndex] = true;
    if (!isRewarder[_newRewarder]) {
      isRewarder[_newRewarder] = true;
    }
  }

  /// @dev Internal function to check if an address is already on the list of rewarders for a given market index
  /// @param _marketIndex uint256 representing the market index to verify
  /// @param _rewarder address of the user's rewarder object to verificar
  /// @return bool value indicating if duplicate entry has been found
  function isDuplicatedRewarder(uint256 _marketIndex, address _rewarder) internal view returns (bool) {
    uint256 length = marketIndexRewarders[_marketIndex].length;
    for (uint256 i; i < length; ) {
      if (marketIndexRewarders[_marketIndex][i] == _rewarder) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }

  /// @dev Check whether a staking token address is already part of a market index
  /// @param _marketIndex uint256 ID of the market index to check on
  /// @param _rewarder Address of the rewarder to check
  /// @return bool indicating whether the staking token was found or not
  function isDuplicatedStakingToken(uint256 _marketIndex, address _rewarder) internal view returns (bool) {
    uint256 length = rewarderMarketIndex[_rewarder].length;
    for (uint256 i; i < length; ) {
      if (rewarderMarketIndex[_rewarder][i] == _marketIndex) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }

  /// @dev Changes the address of the contract's Compounder. Only callable by the current owner.
  ///Emits a `LogSetCompounder` event with previous and new compounder addresses after successful execution of this function.
  ///@param _compounder Address of the new Compounder contract.
  function setCompounder(address _compounder) external onlyOwner {
    emit LogSetCompounder(compounder, _compounder);
    compounder = _compounder;
  }

  /// @dev Set the address of an account authorized to modify balances in CrossMarginTrading.sol contract
  /// Emits a LogSetWhitelistedCaller event.
  /// @param _whitelistedCaller The new address allowed to perform whitelisted calls.
  function setWhitelistedCaller(address _whitelistedCaller) external onlyOwner {
    emit LogSetWhitelistedCaller(whitelistedCaller, _whitelistedCaller);
    whitelistedCaller = _whitelistedCaller;
  }

  /// @dev Deposits _amount tokens from the caller's account to the contract and assign them to _to user's balance for market index _marketIndex.
  /// Only allowed for the whitelisted caller.
  /// If the _marketIndex is not registered, it will revert with TradingStaking_UnknownMarketIndex() error.
  /// Calls onDeposit() function for each rewarder registered on market index _marketIndex using its respective address specified in marketIndexRewarders.
  /// After calling each rewarder, the _amount is added to the user's token balance at the _marketIndex, along with total shares.
  /// Emits a LogDeposit event with information about caller, _to, _marketIndex and _amount.
  ///
  /// Requirements:
  ///
  /// The caller must be whitelisted through setWhitelistedCaller() function.
  /// _to address must be valid.
  /// Calling contract needs to have an allowance of at least _amount on the caller's behalf.
  /// @param _to The address of the primary account
  /// @param _marketIndex Market index
  /// @param _amount Position Size
  function deposit(address _to, uint256 _marketIndex, uint256 _amount) external onlyWhitelistedCaller {
    if (!isMarketIndex[_marketIndex]) revert TradingStaking_UnknownMarketIndex();

    uint256 length = marketIndexRewarders[_marketIndex].length;
    for (uint256 i; i < length; ) {
      address rewarder = marketIndexRewarders[_marketIndex][i];

      IRewarder(rewarder).onDeposit(_to, _amount);

      unchecked {
        ++i;
      }
    }

    userTokenAmount[_marketIndex][_to] += _amount;
    totalShares[_marketIndex] += _amount;

    emit LogDeposit(msg.sender, _to, _marketIndex, _amount);
  }

  function getUserTokenAmount(uint256 _marketIndex, address sender) external view returns (uint256) {
    return userTokenAmount[_marketIndex][sender];
  }

  function getMarketIndexRewarders(uint256 _marketIndex) external view returns (address[] memory) {
    return marketIndexRewarders[_marketIndex];
  }

  function getRewarderMarketIndex(address rewarder) external view returns (uint256[] memory) {
    return rewarderMarketIndex[rewarder];
  }

  function withdraw(address _to, uint256 _marketIndex, uint256 _amount) external onlyWhitelistedCaller {
    _withdraw(_to, _marketIndex, _amount);
  }

  /// @dev Executes the withdrawal process for a given amount of tokens, associated with a certain market index,
  /// to a specified address. Throws if the provided market index does not exist or the user doesn't have enough token,
  /// to execute this transaction.
  /// During the withdrawal process, it will call onWithdraw() for each rewarder associate with this market index and
  /// Subtract the amount tokens from the userTokenAmount and totalShares relating to the provided market index.
  ///
  /// @param _to The Receiver's address where the withdrawn amount should go.
  /// @param _marketIndex The market index for which tokens should be withdrawn.
  /// @param _amount The Amount of tokens that should be withdrawn from the given market index.
  function _withdraw(address _to, uint256 _marketIndex, uint256 _amount) internal {
    if (!isMarketIndex[_marketIndex]) revert TradingStaking_UnknownMarketIndex();
    if (userTokenAmount[_marketIndex][_to] < _amount) revert TradingStaking_InsufficientTokenAmount();

    uint256 length = marketIndexRewarders[_marketIndex].length;
    for (uint256 i; i < length; ) {
      address rewarder = marketIndexRewarders[_marketIndex][i];

      IRewarder(rewarder).onWithdraw(_to, _amount);

      unchecked {
        ++i;
      }
    }
    userTokenAmount[_marketIndex][_to] -= _amount;
    totalShares[_marketIndex] -= _amount;

    emit LogWithdraw(_to, _marketIndex, _amount);
  }

  function harvest(address[] memory _rewarders) external {
    _harvestFor(msg.sender, msg.sender, _rewarders);
  }

  function harvestToCompounder(address _user, address[] memory _rewarders) external {
    if (compounder != msg.sender) revert TradingStaking_NotCompounder();
    _harvestFor(_user, compounder, _rewarders);
  }

  /**

  @dev Internal function to distribute rewards accumulated for provided _user among all of the _rewarders.

  @param _user The address of the user whose rewards are being harvested.

  @param _receiver The address which will receive the rewards.

  @param _rewarders The list containing all the rewarders that will receive their share from the rewards.

  Once passed through a loop and each rewarder receives its own share from the _user's harvest,

  it will automatically emit the LogHarvest() event with respective details including _receiver address,

  _user address, and current time.
  */
  function _harvestFor(address _user, address _receiver, address[] memory _rewarders) internal {
    uint256 length = _rewarders.length;
    for (uint256 i; i < length; ) {
      if (!isRewarder[_rewarders[i]]) {
        revert TradingStaking_NotRewarder();
      }

      IRewarder(_rewarders[i]).onHarvest(_user, _receiver);

      unchecked {
        ++i;
      }
    }
  }

  function calculateShare(address _rewarder, address _user) external view returns (uint256) {
    uint256[] memory marketIndices = rewarderMarketIndex[_rewarder];
    uint256 share = 0;
    uint256 length = marketIndices.length;
    for (uint256 i; i < length; ) {
      share += userTokenAmount[marketIndices[i]][_user];

      unchecked {
        ++i;
      }
    }
    return share;
  }

  function calculateTotalShare(address _rewarder) external view returns (uint256) {
    uint256[] memory marketIndices = rewarderMarketIndex[_rewarder];
    uint256 totalShare = 0;
    uint256 length = marketIndices.length;
    for (uint256 i; i < length; ) {
      totalShare += totalShares[marketIndices[i]];

      unchecked {
        ++i;
      }
    }
    return totalShare;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
