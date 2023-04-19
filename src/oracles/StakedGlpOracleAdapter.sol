// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Owned } from "@hmx/base/Owned.sol";

contract StakedGlpOracleAdapter is Owned, IOracleAdapter {
  event LogSetSGLPAssetId(bytes32 oldSglpAssetId, bytes32 newSglpAssetId);
  error StakedGlpOracleAdapter_BadAssetId();

  IERC20 public immutable sGlp;
  IGmxGlpManager public immutable glpManager;
  bytes32 public sGlpAssetId;

  constructor(IERC20 _sGlp, IGmxGlpManager _glpManager, bytes32 _sGlpAssetId) {
    sGlp = _sGlp;
    glpManager = _glpManager;
    sGlpAssetId = _sGlpAssetId;
  }

  /// @notice Get the latest price of SGLP.
  /// @return The latest price of SGLP in e30.
  /// @return The timestamp of the latest price.
  /// @param _assetId The asset ID of SGLP.
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

  function setSGlpAssetId(bytes32 _newSglpAssetId) external onlyOwner {
    emit LogSetSGLPAssetId(sGlpAssetId, _newSglpAssetId);
    sGlpAssetId = _newSglpAssetId;
  }
}
