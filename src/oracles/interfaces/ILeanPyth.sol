// SPDX-License-Identifier: MIT
//   _   _ __  ____  __
//  | | | |  \/  \ \/ /
//  | |_| | |\/| |\  /
//  |  _  | |  | |/  \
//  |_| |_|_|  |_/_/\_\
//

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

  /// @dev Emitted when a batch price update is processed successfully.
  /// @param chainId ID of the source chain that the batch price update comes from.
  /// @param sequenceNumber Sequence number of the batch price update.
  event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);

  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

  function updatePriceFeeds(bytes[] calldata updateData) external payable;

  function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);
}
