// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPendlePtLpOracle {
  function getOracleState(
    address market,
    uint32 duration
  )
    external
    view
    returns (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied);

  function getPtToSyRate(address market, uint32 duration) external view returns (uint256);
}
