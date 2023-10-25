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
    uint256 indexTokenPrice = _convertToGmxV2Decimals(
      uint256(int256(_buildDatas[indexTokenPriceAssetId].priceE8)),
      30 - indexTokenDecimals
    );
    uint256 longTokenPrice = _convertToGmxV2Decimals(
      uint256(int256(_buildDatas[longTokenPriceAssetId].priceE8)),
      30 - longTokenDecimals
    );
    uint256 shortTokenPrice = _convertToGmxV2Decimals(
      uint256(int256(_buildDatas[shortTokenPriceAssetId].priceE8)),
      30 - shortTokenDecimals
    );

    (int256 gmPrice, ) = reader.getMarketTokenPrice(
      dataStore,
      Market.Props({ marketToken: marketToken, indexToken: indexToken, longToken: longToken, shortToken: shortToken }),
      Price.Props({ min: indexTokenPrice, max: indexTokenPrice }),
      Price.Props({ min: longTokenPrice, max: longTokenPrice }),
      Price.Props({ min: shortTokenPrice, max: shortTokenPrice }),
      MAX_PNL_FACTOR_FOR_DEPOSITS,
      true
    );
    price = gmPrice > 0 ? uint256(gmPrice) / 1e12 : 0;
  }

  /// @notice Return the price of GM Market Token in 18 decimals
  function getPrice(uint256[] memory priceE8s) external view returns (uint256 price) {
    uint256 indexTokenPrice = _convertToGmxV2Decimals(priceE8s[0], 30 - indexTokenDecimals);
    uint256 longTokenPrice = _convertToGmxV2Decimals(priceE8s[1], 30 - longTokenDecimals);
    uint256 shortTokenPrice = _convertToGmxV2Decimals(priceE8s[2], 30 - shortTokenDecimals);

    (int256 gmPrice, ) = reader.getMarketTokenPrice(
      dataStore,
      Market.Props({ marketToken: marketToken, indexToken: indexToken, longToken: longToken, shortToken: shortToken }),
      Price.Props({ min: indexTokenPrice, max: indexTokenPrice }),
      Price.Props({ min: longTokenPrice, max: longTokenPrice }),
      Price.Props({ min: shortTokenPrice, max: shortTokenPrice }),
      MAX_PNL_FACTOR_FOR_DEPOSITS,
      true
    );
    price = gmPrice > 0 ? uint256(gmPrice) / 1e12 : 0;
  }

  function _convertToGmxV2Decimals(
    uint256 priceE8,
    uint256 targetDecimals
  ) internal pure returns (uint256 adjustedPrice) {
    if (targetDecimals - 8 >= 0) {
      adjustedPrice = uint256(priceE8) * 10 ** uint32(targetDecimals - 8);
    } else {
      adjustedPrice = uint256(priceE8) / 10 ** uint32(8 - targetDecimals);
    }
  }
}
