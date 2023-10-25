// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

contract MockGmxV2Oracle {
  // prices in USD * 1e8
  mapping(address => uint256) public prices;

  function setPrices(
    address /* dataStore */,
    address /* eventEmitter */,
    IGmxV2Oracle.SetPricesParams memory params
  ) external {
    for (uint i = 0; i < params.realtimeFeedTokens.length; i++) {
      uint256 price = abi.decode(params.realtimeFeedData[i], (uint256));
      prices[params.realtimeFeedTokens[i]] = price;
    }
  }

  function getPrimaryPrice(address token) external view returns (uint256) {
    uint8 decimals = ERC20(token).decimals();
    uint8 precision = 30 - decimals - 8;
    return prices[token] * (10 ** precision);
  }

  function validateRealtimeFeeds(
    address /* dataStore */,
    address[] memory realtimeFeedTokens,
    bytes[] memory realtimeFeedData
  ) external view returns (IGmxV2Oracle.RealtimeFeedReport[] memory) {
    IGmxV2Oracle.RealtimeFeedReport[] memory reports = new IGmxV2Oracle.RealtimeFeedReport[](realtimeFeedTokens.length);
    for (uint256 i = 0; i < realtimeFeedTokens.length; i++) {
      uint256 price = abi.decode(realtimeFeedData[i], (uint256));
      reports[i] = IGmxV2Oracle.RealtimeFeedReport({
        feedId: 0,
        observationsTimestamp: uint32(block.timestamp),
        median: int192(int256(price)),
        bid: int192(int256(price)),
        ask: int192(int256(price)),
        blocknumberUpperBound: uint64(block.number),
        upperBlockhash: blockhash(block.number),
        blocknumberLowerBound: uint64(block.number),
        currentBlockTimestamp: uint64(block.timestamp)
      });
    }
    return reports;
  }

  function clearAllPrices() external {}
}
