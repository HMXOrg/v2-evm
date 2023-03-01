// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AggregatorV3Interface} from
  "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleAdapterInterface} from "../interfaces/OracleAdapterInterface.sol";

contract ChainlinkAdapter is Owned, OracleAdapterInterface {
  // dependencies
  using SafeCast for int256;

  // errors
  error ChainlinkAdapter_BadLen();
  error ChainlinkAdapter_PriceFeedNotAvailable();
  error ChainlinkAdapter_UnableToFetchPrice();

  // configs
  uint64 public depth;
  // mapping from asset id to source
  mapping(bytes32 => AggregatorV3Interface) public priceFeeds;

  event SetPriceFeed(bytes32 indexed assetId, AggregatorV3Interface source);

  constructor(uint64 _depth) {
    depth = _depth;
  }

  /// @dev Set sources for multiple token pairs
  /// @param assetIds The asset ids to set oracle sources
  /// @param feeds The price feeds to set
  function setPriceFeeds(
    bytes32[] calldata assetIds,
    AggregatorV3Interface[] calldata feeds
  ) external onlyOwner {
    if (assetIds.length != feeds.length) revert ChainlinkAdapter_BadLen();
    for (uint256 i = 0; i < assetIds.length;) {
      priceFeeds[assetIds[i]] = feeds[i];
      emit SetPriceFeed(assetIds[i], feeds[i]);
      unchecked {
        ++i;
      }
    }
  }

  /// @dev Return the price of the given assetId, 30 decimals.
  /// @param assetId The asset id to get price
  /// @param isMax Whether to get the max price or min price.
  function getLatestPrice(bytes32 assetId, bool isMax)
    external
    view
    override
    returns (uint256, uint256)
  {
    if (address(priceFeeds[assetId]) == address(0)) {
      revert ChainlinkAdapter_PriceFeedNotAvailable();
    }

    AggregatorV3Interface priceFeed = priceFeeds[assetId];
    uint256 price = 0;
    int256 _priceCursor = 0;
    uint256 priceCursor = 0;
    uint256 timestampCursor = 0;
    (uint80 latestRoundId, int256 latestAnswer,, uint256 timestamp,) =
      priceFeed.latestRoundData();

    for (uint80 i = 0; i < depth; i++) {
      if (i >= latestRoundId) break;

      if (i == 0) {
        priceCursor = latestAnswer.toUint256();
      } else {
        (, _priceCursor,, timestampCursor,) =
          priceFeed.getRoundData(latestRoundId - i);
        priceCursor = _priceCursor.toUint256();
      }

      if (price == 0) {
        price = priceCursor;
        continue;
      }

      if (isMax && price < priceCursor) {
        price = priceCursor;
        timestamp = timestampCursor;
        continue;
      }

      if (!isMax && price > priceCursor) {
        price = priceCursor;
        timestamp = timestampCursor;
      }
    }

    if (price == 0) revert ChainlinkAdapter_UnableToFetchPrice();

    return ((price * 1e30) / 10 ** priceFeed.decimals(), timestamp);
  }
}
