// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ICalcPriceAdapter } from "@hmx/oracles/interfaces/ICalcPriceAdapter.sol";
import { IPendlePtLpOracle } from "@hmx/oracles/interfaces/IPendlePtLpOracle.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

contract PendlePTAdapter is ICalcPriceAdapter {
  error PendlePTAdapter_OracleNotInitialized();

  uint256 public assetPriceAssetId;
  address public marketAddress;
  IPendlePtLpOracle public pendlePtLpOracle;
  uint32 public twapDuration;

  constructor(uint256 assetPriceAssetId_, address marketAddress_, address pendlePtLpOracle_, uint32 twapDuration_) {
    assetPriceAssetId = assetPriceAssetId_;
    marketAddress = marketAddress_;
    pendlePtLpOracle = IPendlePtLpOracle(pendlePtLpOracle_);
    twapDuration = twapDuration_;

    // Check if the oracle is initialized. If it is not, please initialize before deploying this contract.
    (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = pendlePtLpOracle.getOracleState(
      marketAddress,
      twapDuration
    );
    if (increaseCardinalityRequired || !oldestObservationSatisfied) revert PendlePTAdapter_OracleNotInitialized();
  }

  /// @notice Return the price of PT token in 18 decimals
  function getPrice() external view returns (uint256 price) {
    price = pendlePtLpOracle.getPtToSyRate(marketAddress, twapDuration);
  }

  function getPrice(IEcoPythCalldataBuilder3.BuildData[] calldata _buildDatas) external view returns (uint256 price) {
    uint256 priceE18 = uint256(int256(_buildDatas[assetPriceAssetId].priceE8)) * 1e10;
    uint256 ptRate = pendlePtLpOracle.getPtToSyRate(marketAddress, twapDuration);
    price = (priceE18 * ptRate) / 1e18;
  }

  function getPrice(uint256[] memory priceE8s) external view returns (uint256 price) {
    uint256 priceE18 = priceE8s[0] * 1e10;
    uint256 ptRate = pendlePtLpOracle.getPtToSyRate(marketAddress, twapDuration);
    price = (priceE18 * ptRate) / 1e18;
  }
}
