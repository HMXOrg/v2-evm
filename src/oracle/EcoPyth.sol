// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { IPythPriceInfo, IEcoPythPriceInfo } from "./interfaces/IPyth.sol";
import { IEcoPyth } from "./interfaces/IEcoPyth.sol";

contract EcoPyth is Owned, IEcoPyth {
  // errors
  error EcoPyth_ExpectZeroFee();
  error EcoPyth_OnlyUpdater();
  error EcoPyth_PriceFeedNotFound();

  // mapping of our asset id to Pyth's price id
  mapping(bytes32 => IEcoPythPriceInfo) public priceInfos;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdaters;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);
  event LogVaas(bytes32 _encodedVaas);

  // type(uint128).max is 128 bits of 1s
  // shift the 1s by (128 - 64) to get (128 - 64) 0s followed by 64 1s
  uint128 public constant BITMASK_64 = type(uint128).max >> (128 - 64);

  /**
   * Modifiers
   */
  modifier onlyUpdater() {
    if (!isUpdaters[msg.sender]) {
      revert EcoPyth_OnlyUpdater();
    }
    _;
  }

  constructor() {}

  /// @dev Updates price feeds for a set of price IDs with new price data. Only authorized accounts can call this function.
  /// The function loops through each price ID in _priceIds, retrieves the corresponding _newPriceInfo by calling the
  /// _parsePriceInfo internal function on the corresponding packed price data from _packedPriceDatas. If the _newPriceInfo
  /// has a more recent timestamp than the existing price info for that ID, the function updates the priceInfos mapping for
  /// that ID with the new price info. Finally, the function emits the LogVaas event with the given _encodedVaas message.
  /// @param _priceIds An array of bytes32 price IDs that correspond to the price data being updated.
  /// @param _packedPriceDatas An array of uint128 packed price data with information on the latest price updates for each price ID.
  /// @param _encodedVaas The encoded Vaas message for the update.
  function updatePriceFeeds(
    bytes32[] calldata _priceIds,
    uint128[] calldata _packedPriceDatas,
    bytes32 _encodedVaas
  ) external onlyUpdater {
    // Loop through all of the price data
    uint256 _len = _priceIds.length;
    if (_len == 0) return;

    for (uint256 i = 0; i < _len; ) {
      bytes32 _priceId = _priceIds[i];
      IEcoPythPriceInfo memory _newPriceInfo = _parsePriceInfo(_packedPriceDatas[i]);

      // Update the price if the new one is more fresh
      uint256 _lastPublishTime = priceInfos[_priceId].publishTime;
      if (_lastPublishTime < _newPriceInfo.publishTime) {
        // Price information is more recent than the existing price information.
        priceInfos[_priceId] = _newPriceInfo;
      }

      unchecked {
        ++i;
      }
    }

    emit LogVaas(_encodedVaas);
  }

  /// @dev Returns the current price for the given price feed ID. Revert if price never got fed.
  /// @param id The unique identifier of the price feed.
  /// @return price The current price.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    IEcoPythPriceInfo storage priceInfo = priceInfos[id];
    if (priceInfo.publishTime == 0) revert EcoPyth_PriceFeedNotFound();

    price.publishTime = priceInfo.publishTime;
    price.expo = -8;
    price.price = priceInfo.price;
    price.conf = 0;
    return price;
  }

  /// @dev Returns the update fee for the given price feed update data.
  /// @return feeAmount The update fee, which is always 0.
  function getUpdateFee(bytes[] calldata /*updateData*/) external pure returns (uint feeAmount) {
    // The update fee is always 0, so simply return 0
    return 0;
  }

  /// @dev Sets the `isActive` status of the given account as a price updater.
  /// @param _account The account address to update.
  /// @param _isActive The new status of the account as a price updater.
  function setUpdater(address _account, bool _isActive) external onlyOwner {
    // Set the `isActive` status of the given account
    isUpdaters[_account] = _isActive;

    // Emit a `LogSetUpdater` event indicating the updated status of the account
    emit LogSetUpdater(_account, _isActive);
  }

  /// @dev Parses packed price data to an IEcoPythPriceInfo structure. Delegates to an internal function for parsing.
  /// @param _packedPriceData Packaged price data to be parsed
  /// @return _priceInfo Parsed price information in the IEcoPythPriceInfo structure
  function parsePriceInfo(uint128 _packedPriceData) external pure returns (IEcoPythPriceInfo memory _priceInfo) {
    return _parsePriceInfo(_packedPriceData);
  }

  /// @dev Internal function to parses packed price data to an IEcoPythPriceInfo structure.
  /// The function takes in a packed price data and returns the decoded information in an IEcoPythPriceInfo structure.
  /// The packed price data is first split into its constituent parts using bit shifting operations.
  /// The publish time, expo, price and confidence values are extracted from the packed price data and assigned
  /// to corresponding fields in _priceInfo structure. The resultant _priceInfo structure is then returned.
  /// @param _packedPriceData Packaged price data to be parsed
  /// @return _priceInfo Parsed price information in the IEcoPythPriceInfo structure
  function _parsePriceInfo(uint128 _packedPriceData) internal pure returns (IEcoPythPriceInfo memory _priceInfo) {
    _priceInfo.publishTime = uint64((_packedPriceData >> (128 - 64)) & BITMASK_64);
    _priceInfo.price = int64(uint64((_packedPriceData >> (0)) & BITMASK_64));
    return _priceInfo;
  }

  /// @dev Function to construct a packed price data as a bytes32 integer.
  /// @param _publishTime Timestamp when the price was published.
  /// @param _price Price value represented as an int64.
  /// @return A bytes32 integer that represents the packed price data.
  function buildPackedPriceData(uint64 _publishTime, int64 _price) external pure returns (uint128) {
    return _buildPackedPriceData(_publishTime, _price);
  }

  /// @dev Internal function to construct a packed price data as a bytes32 integer.
  /// This function takes in the same four input parameters as the buildPackedPriceData function and returns a bytes32 integer that represents
  /// the packed price data. This packed price data is constructed by concatenating the four input variables using the abi.encodePacked function,
  /// which returns a bytes array that is then cast to bytes32.
  /// @param _publishTime Timestamp when the price was published.
  /// @param _price Price value represented as an int64.
  /// @return A bytes32 integer that represents the packed price data.
  function _buildPackedPriceData(uint64 _publishTime, int64 _price) internal pure returns (uint128) {
    return uint128(bytes16(abi.encodePacked(_publishTime, _price)));
  }
}
