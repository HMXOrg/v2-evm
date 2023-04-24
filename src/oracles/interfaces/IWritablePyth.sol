// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IWritablePyth {
  function updatePriceFeeds(
    bytes32[] calldata _priceIds,
    uint256[] calldata _packedPriceDatas,
    bytes32 _encodedVaas
  ) external;
}
