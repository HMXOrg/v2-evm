// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract StakedGlpOracleAdapter is OwnableUpgradeable, IOracleAdapter {
  event LogSetSGLPAssetId(bytes32 oldSglpAssetId, bytes32 newSglpAssetId);
  error StakedGlpOracleAdapter_BadAssetId();

  IERC20Upgradeable public sGlp;
  IGmxGlpManager public glpManager;
  bytes32 public sGlpAssetId;

  function initialize(IERC20Upgradeable _sGlp, IGmxGlpManager _glpManager, bytes32 _sGlpAssetId) external initializer {
    OwnableUpgradeable.__Ownable_init();

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

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
