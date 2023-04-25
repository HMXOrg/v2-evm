// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PythStructs } from "lib/pyth-sdk-solidity/IPyth.sol";

interface IEcoPyth {
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

  function updatePriceFeeds(
    bytes32[] calldata _prices,
    bytes32[] calldata _publishTimeDiff,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external;
}
