// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IReadablePyth } from "./IReadablePyth.sol";
import { IOracleAdapter } from "./IOracleAdapter.sol";

interface ICIXPythAdapter is IOracleAdapter {
  struct CIXPythPriceConfig {
    /// @dev A magic constant in which needed to reconfig everytime we adjust the weight to keep the basket balance.
    uint256 cE8;
    /// @dev An array price id defined by Pyth. This array index is relative to weightsE8.
    bytes32[] pythPriceIds;
    /// @dev An array of weight of asset in E8 basis. If weight is 0.2356, this value should be 23560000. This array index is relative to pythPriceIds.
    uint256[] weightsE8;
  }

  function pyth() external returns (IReadablePyth);

  function setConfig(
    bytes32 _assetId,
    uint256 _cE8,
    bytes32[] memory _pythPriceIds,
    uint256[] memory _weightsE8
  ) external;

  function getConfigByAssetId(bytes32 _assetId) external view returns (CIXPythPriceConfig memory);
}
