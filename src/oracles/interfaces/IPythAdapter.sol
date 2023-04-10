// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ILeanPyth } from "./ILeanPyth.sol";
import { IOracleAdapter } from "./IOracleAdapter.sol";

interface IPythAdapter is IOracleAdapter {
  struct PythPriceConfig {
    /// @dev Price id defined by Pyth.
    bytes32 pythPriceId;
    /// @dev If true, return final price as `1/price`. This config intend to support thr price pair like USD/JPY (invert USD quote).
    bool inverse;
  }

  function pyth() external returns (ILeanPyth);

  function setConfig(bytes32 _assetId, bytes32 _pythPriceId, bool _inverse) external;

  function configs(bytes32 _assetId) external view returns (bytes32 _pythPriceId, bool _inverse);
}
