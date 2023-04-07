// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { TickMath } from "@hmx/libraries/TickMath.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { IPythPriceInfo, IEcoPythPriceInfo } from "./interfaces/IPyth.sol";
import { IEcoPyth } from "./interfaces/IEcoPyth.sol";
import { console } from "forge-std/console.sol";

contract EcoPyth is Owned, IEcoPyth {
  // errors
  error EcoPyth_ExpectZeroFee();
  error EcoPyth_OnlyUpdater();
  error EcoPyth_PriceFeedNotFound();
  error EcoPyth_AssetHasAlreadyBeenDefined();

  // array of price data
  bytes32[] public prices;
  uint256 public publishTime;
  mapping(bytes32 => uint256) public mapPriceIdToIndex;
  uint256 public indexCount;
  uint256 public constant MAX_PRICE_PER_WORD = 10;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdaters;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);
  event LogVaas(bytes32 _encodedVaas);

  /**
   * Modifiers
   */
  modifier onlyUpdater() {
    if (!isUpdaters[msg.sender]) {
      revert EcoPyth_OnlyUpdater();
    }
    _;
  }

  constructor() {
    // Preoccupied index 0 as any of `mapPriceIdToIndex` returns default as 0
    indexCount = 1;
  }

  function updatePriceFeeds(bytes32[] calldata _prices, bytes32 _encodedVaas) external onlyUpdater {
    prices = _prices;
    publishTime = block.timestamp;

    emit LogVaas(_encodedVaas);
  }

  /// @dev Returns the current price for the given price feed ID. Revert if price never got fed.
  /// @param id The unique identifier of the price feed.
  /// @return price The current price.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    uint256 index = mapPriceIdToIndex[id] - 1;
    console.log("realIndex", mapPriceIdToIndex[id]);
    console.log("index", index);
    uint256 internalIndex = index % 10;
    uint256 word = uint256(prices[index / 10]);
    int24 tick = int24(int256((word >> (256 - (24 * (internalIndex + 1))))));
    uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    console.log("sqrtPriceX96", sqrtPriceX96);
    uint256 spotPrice = (uint256(sqrtPriceX96) * (uint256(sqrtPriceX96)) * (1e8)) >> (96 * 2);
    console.log("spotPrice", spotPrice);

    price.publishTime = publishTime;
    price.expo = -8;
    price.price = int64(int256(spotPrice));
    price.conf = 0;
    return price;
  }

  /// @dev Returns the update fee for the given price feed update data.
  /// @return feeAmount The update fee, which is always 0.
  function getUpdateFee(bytes[] calldata /*updateData*/) external pure returns (uint feeAmount) {
    // The update fee is always 0, so simply return 0
    return 0;
  }

  /// @dev Sets the `isActive` status of the given account as a price updater.
  /// @param _account The account address to update.
  /// @param _isActive The new status of the account as a price updater.
  function setUpdater(address _account, bool _isActive) external onlyOwner {
    // Set the `isActive` status of the given account
    isUpdaters[_account] = _isActive;

    // Emit a `LogSetUpdater` event indicating the updated status of the account
    emit LogSetUpdater(_account, _isActive);
  }

  function insertAssets(bytes32[] calldata _assetIds) external onlyOwner {
    uint256 _len = _assetIds.length;
    for (uint256 i = 0; i < _len; ) {
      _insertAsset(_assetIds[i]);

      unchecked {
        ++i;
      }
    }
  }

  function insertAsset(bytes32 _assetId) external onlyOwner {
    _insertAsset(_assetId);
  }

  function _insertAsset(bytes32 _assetId) internal {
    if (mapPriceIdToIndex[_assetId] != 0) revert EcoPyth_AssetHasAlreadyBeenDefined();
    mapPriceIdToIndex[_assetId] = indexCount;
    ++indexCount;
  }

  function buildUpdateData(int24[] calldata _prices) external pure returns (bytes32[] memory _updateData) {
    _updateData = new bytes32[](_prices.length / MAX_PRICE_PER_WORD + 1);
    _updateData[0] = bytes32(uint256(0));
    for (uint256 i; i < _prices.length; i++) {
      uint256 outerIndex = i / MAX_PRICE_PER_WORD;
      uint256 innerIndex = i % MAX_PRICE_PER_WORD;

      bytes32 partialWord = bytes32(
        abi.encodePacked(
          innerIndex == 0 ? _prices[i] : int24(0),
          innerIndex == 1 ? _prices[i] : int24(0),
          innerIndex == 2 ? _prices[i] : int24(0),
          innerIndex == 3 ? _prices[i] : int24(0),
          innerIndex == 4 ? _prices[i] : int24(0),
          innerIndex == 5 ? _prices[i] : int24(0),
          innerIndex == 6 ? _prices[i] : int24(0),
          innerIndex == 7 ? _prices[i] : int24(0),
          innerIndex == 8 ? _prices[i] : int24(0),
          innerIndex == 9 ? _prices[i] : int24(0)
        )
      );
      bytes32 previousWord = _updateData[outerIndex];

      _updateData[outerIndex] = previousWord | partialWord;
    }
  }
}
