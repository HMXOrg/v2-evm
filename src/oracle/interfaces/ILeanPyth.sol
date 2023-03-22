// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth, PythStructs, IPythEvents } from "pyth-sdk-solidity/IPyth.sol";

interface ILeanPyth {
  /// @dev Emitted when the price feed with `id` has received a fresh update.
  /// @param id The Pyth Price Feed ID.
  /// @param publishTime Publish time of the given price update.
  /// @param price Price of the given price update.
  /// @param conf Confidence interval of the given price update.
  /// @param encodedVm The submitted calldata. Use this verify integrity of price data.
  event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf, bytes encodedVm);

  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

  function updatePriceFeeds(bytes[] calldata updateData) external payable;

  function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);
}
