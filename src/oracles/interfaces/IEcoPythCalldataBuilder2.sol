// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IEcoPythCalldataBuilder2 {
  struct BuildData {
    bytes32 assetId;
    int64 priceE8;
    uint160 publishTime;
    uint32 maxDiffBps;
  }

  function build(
    BuildData[] calldata _data
  )
    external
    view
    returns (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
      uint256 blockNumber
    );
}
