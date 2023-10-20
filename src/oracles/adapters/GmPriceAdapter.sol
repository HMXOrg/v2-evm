// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IGmxV2Reader } from "@hmx/interfaces/gmxV2/IGmxV2Reader.sol";
import { Price } from "@hmx/interfaces/gmxV2/Price.sol";
import { Market } from "@hmx/interfaces/gmxV2/Market.sol";
import { ICalcPriceAdapter } from "@hmx/oracles/interfaces/ICalcPriceAdapter.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

contract GmPriceAdapter is ICalcPriceAdapter {
  bytes32 public constant MAX_PNL_FACTOR_FOR_DEPOSITS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_DEPOSITS"));

  IGmxV2Reader public reader;
  address public dataStore;
  address public marketToken;
  address public indexToken;
  uint256 public indexTokenDecimals;
  address public longToken;
  uint256 public longTokenDecimals;
  address public shortToken;
  uint256 public shortTokenDecimals;
  uint256 public indexTokenPriceAssetId;
  uint256 public longTokenPriceAssetId;
  uint256 public shortTokenPriceAssetId;

  constructor(
    IGmxV2Reader reader_,
    address dataStore_,
    address marketToken_,
    address indexToken_,
    uint256 indexTokenDecimals_,
    address longToken_,
    uint256 longTokenDecimals_,
    address shortToken_,
    uint256 shortTokenDecimals_,
    uint256 indexTokenPriceAssetId_,
    uint256 longTokenPriceAssetId_,
    uint256 shortTokenPriceAssetId_
  ) {
    reader = reader_;
    dataStore = dataStore_;
    marketToken = marketToken_;
    indexToken = indexToken_;
    indexTokenDecimals = indexTokenDecimals_;
    longToken = longToken_;
    longTokenDecimals = longTokenDecimals_;
    shortToken = shortToken_;
    shortTokenDecimals = shortTokenDecimals_;
    indexTokenPriceAssetId = indexTokenPriceAssetId_;
    longTokenPriceAssetId = longTokenPriceAssetId_;
    shortTokenPriceAssetId = shortTokenPriceAssetId_;
  }

  /// @notice Return the price of GM Market Token in 18 decimals
  function getPrice(IEcoPythCalldataBuilder3.BuildData[] calldata _buildDatas) external view returns (uint256 price) {
    (int256 gmPrice, ) = reader.getMarketTokenPrice(
      dataStore,
      Market.Props({ marketToken: marketToken, indexToken: indexToken, longToken: longToken, shortToken: shortToken }),
      Price.Props({
        min: _convertToGmxV2Decimals(_buildDatas[indexTokenPriceAssetId].priceE8, 30 - indexTokenDecimals),
        max: _convertToGmxV2Decimals(_buildDatas[indexTokenPriceAssetId].priceE8, 30 - indexTokenDecimals)
      }),
      Price.Props({
        min: _convertToGmxV2Decimals(_buildDatas[longTokenPriceAssetId].priceE8, 30 - longTokenDecimals),
        max: _convertToGmxV2Decimals(_buildDatas[longTokenPriceAssetId].priceE8, 30 - longTokenDecimals)
      }),
      Price.Props({
        min: _convertToGmxV2Decimals(_buildDatas[shortTokenPriceAssetId].priceE8, 30 - shortTokenDecimals),
        max: _convertToGmxV2Decimals(_buildDatas[shortTokenPriceAssetId].priceE8, 30 - shortTokenDecimals)
      }),
      MAX_PNL_FACTOR_FOR_DEPOSITS,
      true
    );
    price = gmPrice > 0 ? uint256(gmPrice) / 1e12 : 0;
  }

  function _convertToGmxV2Decimals(
    int64 priceE8,
    uint256 targetDecimals
  ) internal pure returns (uint256 adjustedPrice) {
    uint256 price = uint256(int256(priceE8));
    if (targetDecimals - 8 >= 0) {
      adjustedPrice = uint256(price) * 10 ** uint32(targetDecimals - 8);
    } else {
      adjustedPrice = uint256(price) / 10 ** uint32(8 - targetDecimals);
    }
  }
}
