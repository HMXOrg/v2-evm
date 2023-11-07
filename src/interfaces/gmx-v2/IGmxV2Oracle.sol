// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2Types } from "@hmx/interfaces/gmx-v2/IGmxV2Types.sol";

interface IGmxV2Oracle {
  struct SetPricesParams {
    uint256 signerInfo;
    address[] tokens;
    uint256[] compactedMinOracleBlockNumbers;
    uint256[] compactedMaxOracleBlockNumbers;
    uint256[] compactedOracleTimestamps;
    uint256[] compactedDecimals;
    uint256[] compactedMinPrices;
    uint256[] compactedMinPricesIndexes;
    uint256[] compactedMaxPrices;
    uint256[] compactedMaxPricesIndexes;
    bytes[] signatures;
    address[] priceFeedTokens;
    address[] realtimeFeedTokens;
    bytes[] realtimeFeedData;
  }

  struct RealtimeFeedReport {
    // The feed ID the report has data for
    bytes32 feedId;
    // The time the median value was observed on
    uint32 observationsTimestamp;
    // The median value agreed in an OCR round
    int192 median;
    // The best bid value agreed in an OCR round
    // bid is the highest price that a buyer will buy at
    int192 bid;
    // The best ask value agreed in an OCR round
    // ask is the lowest price that a seller will sell at
    int192 ask;
    // The upper bound of the block range the median value was observed within
    uint64 blocknumberUpperBound;
    // The blockhash for the upper bound of block range (ensures correct blockchain)
    bytes32 upperBlockhash;
    // The lower bound of the block range the median value was observed within
    uint64 blocknumberLowerBound;
    // The timestamp of the current (upperbound) block number
    uint64 currentBlockTimestamp;
  }

  function getPrimaryPrice(address token) external view returns (IGmxV2Types.PriceProps memory);
}
