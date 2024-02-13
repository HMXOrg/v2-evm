// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IYBToken } from "@hmx/interfaces/blast/IYBToken.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { ICalcPriceAdapter } from "@hmx/oracles/interfaces/ICalcPriceAdapter.sol";

/// @notice ybTKN Price Adapter - Calculate the USD price of ybTKN
contract YbPriceAdapter is ICalcPriceAdapter {
  // Errors
  error YbPriceAdapter_MissingPriceFromBuildData();

  // Configs
  IYBToken public yb;
  bytes32 public baseAssetId;

  constructor(IYBToken _yb, bytes32 _baseAssetId) {
    yb = _yb;
    baseAssetId = _baseAssetId;
  }

  function getPrice(
    IEcoPythCalldataBuilder3.BuildData[] calldata _buildDatas
  ) external view returns (uint256 _priceE18) {
    // Get price from Pyth
    uint256 _priceE8 = _getPriceE8ByAssetId(baseAssetId, _buildDatas);
    uint256 _ybBaseConversionE18 = yb.previewRedeem(1 ether);
    _priceE18 = (_priceE8 * _ybBaseConversionE18) / 1e8;
  }

  function getPrice(uint256[] memory priceE8s) external view returns (uint256 _priceE18) {
    uint256 _ybBaseConversionE18 = yb.previewRedeem(1 ether);
    _priceE18 = (priceE8s[0] * _ybBaseConversionE18) / 1e8;
  }

  function _getPriceE8ByAssetId(
    bytes32 _assetId,
    IEcoPythCalldataBuilder3.BuildData[] memory _buildDatas
  ) private pure returns (uint256 _priceE8) {
    uint256 _len = _buildDatas.length;
    for (uint256 i = 0; i < _len; ) {
      if (_assetId == _buildDatas[i].assetId) return uint256(int256(_buildDatas[i].priceE8));

      unchecked {
        ++i;
      }
    }

    if (_priceE8 == 0) revert YbPriceAdapter_MissingPriceFromBuildData();
  }
}
