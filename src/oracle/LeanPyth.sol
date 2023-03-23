// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { IPyth, PythStructs, IPythEvents } from "pyth-sdk-solidity/IPyth.sol";
import { ILeanPyth } from "./interfaces/ILeanPyth.sol";

contract LeanPyth is Owned, ILeanPyth {
  // errors
  error LeanPyth_ExpectZeroFee();
  error LeanPyth_OnlyUpdater();
  error LeanPyth_PriceFeedNotFound();

  // mapping of our asset id to Pyth's price id
  mapping(bytes32 => PythStructs.PriceFeed) priceFeeds;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdater;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);

  /**
   * Modifiers
   */
  modifier onlyUpdater() {
    if (!isUpdater[msg.sender]) {
      revert LeanPyth_OnlyUpdater();
    }
    _;
  }

  /// @dev Updates the price feeds with the given price data.
  /// @notice The function must not be called with any msg.value. (Define as payable for IPyth compatability)
  /// @param updateData The array of encoded price feeds to update.
  function updatePriceFeeds(bytes[] calldata updateData) public payable override {
    // The function is payable (to make it IPyth compat), so there is a chance msg.value is submitted.
    // On LeanPyth, we do not collect any fee.
    if (msg.value > 0) revert LeanPyth_ExpectZeroFee();

    // Loop through all of the price data
    for (uint i = 0; i < updateData.length; ) {
      // Decode
      PythStructs.PriceFeed memory priceFeed = abi.decode(updateData[i], (PythStructs.PriceFeed));

      // Update the price if the new one is more fresh
      uint lastPublishTime = priceFeeds[priceFeed.id].price.publishTime;
      if (lastPublishTime < priceFeed.price.publishTime) {
        // Price information is more recent than the existing price information.
        priceFeeds[priceFeed.id] = priceFeed;
        emit PriceFeedUpdate(
          priceFeed.id,
          uint64(lastPublishTime),
          priceFeed.price.price,
          priceFeed.price.conf,
          // User can use this data to verify data integrity via wormhole().parseAndVerifyVM(encodedVm)
          updateData[i]
        );
      }

      unchecked {
        ++i;
      }
    }
  }

  /// @dev Returns the current price for the given price feed ID. Revert if price never got fed.
  /// @param id The unique identifier of the price feed.
  /// @return price The current price.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    PythStructs.PriceFeed storage priceFeed = priceFeeds[id];
    if (priceFeed.price.publishTime == 0) revert LeanPyth_PriceFeedNotFound();
    return priceFeed.price;
  }

  /// @dev Returns the update fee for the given price feed update data.
  /// @return feeAmount The update fee, which is always 0.
  function getUpdateFee(bytes[] calldata /*updateData*/) external pure returns (uint) {
    // The update fee is always 0, so simply return 0
    return 0;
  }

  /// @dev Sets the `isActive` status of the given account as a price updater.
  /// @param _account The account address to update.
  /// @param _isActive The new status of the account as a price updater.
  function setUpdater(address _account, bool _isActive) external onlyOwner {
    // Set the `isActive` status of the given account
    isUpdater[_account] = _isActive;

    // Emit a `LogSetUpdater` event indicating the updated status of the account
    emit LogSetUpdater(_account, _isActive);
  }
}
