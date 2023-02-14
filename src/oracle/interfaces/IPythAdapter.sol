// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPythAdapter {
  function updatePrices(bytes[] memory _priceUpdateData) external payable;

  function getUpdateFee(
    bytes[] memory _priceUpdateData
  ) external view returns (uint256);
}
