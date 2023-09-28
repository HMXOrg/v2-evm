// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

interface ILiquidationReader {
  function getLiquidatableSubAccount(
    uint64 _activeSubaccountLimit,
    uint64 _activeSubaccountOffset,
    bytes32[] memory _assetIds,
    uint64[] memory _pricesE8,
    bool[] memory _shouldInverts
  ) external view returns (address[] memory);
}
