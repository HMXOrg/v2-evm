// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IPriceAdapter } from "@hmx/oracles/interfaces/IPriceAdapter.sol";
import { IPendlePtLpOracle } from "@hmx/oracles/interfaces/IPendlePtLpOracle.sol";

contract PendlePTAdapter is IPriceAdapter {
  error BadDecimals();

  address public marketAddress;
  IPendlePtLpOracle public pendlePtLpOracle;
  uint32 public twapDuration;

  constructor(address marketAddress_, address pendlePtLpOracle_, uint32 twapDuration_) {
    marketAddress = marketAddress_;
    pendlePtLpOracle = IPendlePtLpOracle(pendlePtLpOracle_);
    twapDuration = twapDuration_;

    // Check if the oracle is initialized. If it is not, please initialize before deploying this contract.
    (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = pendlePtLpOracle.getOracleState(
      marketAddress,
      twapDuration
    );
    assert(!increaseCardinalityRequired);
    assert(oldestObservationSatisfied);
  }

  /// @notice Return the price of PT token in 18 decimals
  function getPrice() external view returns (uint256 price) {}
}
