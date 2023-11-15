// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ICalcPriceAdapter } from "./ICalcPriceAdapter.sol";

interface ICIXPriceAdapter is ICalcPriceAdapter {
  struct CIXConfig {
    /// @dev A magic constant in which needed to reconfig everytime we adjust the weight to keep the basket balance.
    uint256 cE8;
    /// @dev An array asset id defined by HMX. This array index is relative to weightsE8.
    bytes32[] assetIds;
    /// @dev An array of weight of asset in E8 basis. If weight is 0.2356, this value should be 23560000. This array index is relative to assetIds.
    uint256[] weightsE8;
    /// @dev An array of boolean. Config this to true, if the asset quoted with USD. (EURUSD -> true, USDJPY -> false)
    bool[] usdQuoteds;
  }

  function setConfig(
    uint256 _cE8,
    bytes32[] memory _pythPriceIds,
    uint256[] memory _weightsE8,
    bool[] memory _usdQuoteds
  ) external;
}
