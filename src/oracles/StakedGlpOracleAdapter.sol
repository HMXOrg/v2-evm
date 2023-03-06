// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";
import { IGmxGlpManager } from "@hmx/vendors/gmx/IGmxGlpManager.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakedGlpOracleAdapter is IOracleAdapter {
  using AddressUtils for address;

  error StakedGlpOracleAdapter_BadAssetId();

  IERC20 public immutable sGlp;
  IGmxGlpManager public immutable glpManager;
  bytes32 public immutable sGlpAssetId;

  constructor(IERC20 _sGlp, IGmxGlpManager _glpManager, bytes32 _sGlpAssetId) {
    sGlp = _sGlp;
    glpManager = _glpManager;
    sGlpAssetId = _sGlpAssetId;
  }

  /// @notice Get the latest price of GLP.
  /// @return The latest price of GLP in e30.
  /// @return The timestamp of the latest price.
  /// @param _assetId The asset ID of GLP.
  /// @param _isMax Whether to get the max price.
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint32 /* _confidenceThreshold */
  ) external view override returns (uint256, uint256) {
    // Check
    if (_assetId != sGlpAssetId) {
      revert StakedGlpOracleAdapter_BadAssetId();
    }

    return ((1e18 * glpManager.getAum(_isMax)) / sGlp.totalSupply(), block.timestamp);
  }
}
