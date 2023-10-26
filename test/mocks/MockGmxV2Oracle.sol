// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IGmxV2Price } from "@hmx/interfaces/gmx-v2/IGmxV2Price.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

contract MockGmxV2Oracle is IGmxV2Oracle {
  mapping(address => IGmxV2Price.Props) public prices;

  function setPrices(address /* dataStore */, address /* eventEmitter */, SetPricesParams memory params) external {
    for (uint i = 0; i < params.realtimeFeedTokens.length; i++) {
      (uint256 min, uint256 max) = abi.decode(params.realtimeFeedData[i], (uint256, uint256));
      prices[params.realtimeFeedTokens[i]] = IGmxV2Price.Props({ min: min, max: max });
    }
  }

  function getPrimaryPrice(address token) external view returns (IGmxV2Price.Props memory) {
    return prices[token];
  }

  function validateRealtimeFeeds(
    address /* dataStore */,
    address[] memory realtimeFeedTokens,
    bytes[] memory realtimeFeedData
  ) external view returns (RealtimeFeedReport[] memory) {
    RealtimeFeedReport[] memory reports = new IGmxV2Oracle.RealtimeFeedReport[](realtimeFeedTokens.length);
    for (uint256 i = 0; i < realtimeFeedTokens.length; i++) {
      uint256 price = abi.decode(realtimeFeedData[i], (uint256));
      reports[i] = RealtimeFeedReport({
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
