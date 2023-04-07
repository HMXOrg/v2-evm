// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
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
  uint112[65_536] public packedPriceInfos;
  bytes32[] public prices;
  bytes32[] public publishTimes;
  uint256 public packedPriceInfosLength;
  mapping(bytes32 => uint256) public mapPriceIdToIndex;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdaters;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);
  event LogVaas(bytes32 _encodedVaas);

  // type(uint128).max is 128 bits of 1s
  // shift the 1s by (128 - n) to get (128 - n) 0s followed by n 1s
  uint128 public constant BITMASK_64_OF_128 = type(uint128).max >> (128 - 64);
  uint128 public constant BITMASK_48_OF_128 = type(uint128).max >> (128 - 48);
  uint128 public constant BITMASK_16_OF_128 = type(uint128).max >> (128 - 16);

  uint112 public constant BITMASK_64_OF_112 = type(uint112).max >> (112 - 64);
  uint112 public constant BITMASK_48_OF_112 = type(uint112).max >> (112 - 48);

  uint256 public constant BITMASK_24_OF_256 = type(uint256).max >> (256 - 24);
  uint256 public constant BITMASK_48_OF_256 = type(uint256).max >> (256 - 48);
  uint256 public constant BITMASK_72_OF_256 = type(uint256).max >> (256 - 72);
  uint256 public constant BITMASK_96_OF_256 = type(uint256).max >> (256 - 96);
  uint256 public constant BITMASK_120_OF_256 = type(uint256).max >> (256 - 120);
  uint256 public constant BITMASK_144_OF_256 = type(uint256).max >> (256 - 144);
  uint256 public constant BITMASK_168_OF_256 = type(uint256).max >> (256 - 168);
  uint256 public constant BITMASK_192_OF_256 = type(uint256).max >> (256 - 192);
  uint256 public constant BITMASK_216_OF_256 = type(uint256).max >> (256 - 216);
  uint256 public constant BITMASK_240_OF_256 = type(uint256).max >> 24;

  uint256[10] public BITMASKS;

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
    packedPriceInfosLength = 1;

    BITMASKS[9] = BITMASK_24_OF_256;
    BITMASKS[8] = BITMASK_48_OF_256;
    BITMASKS[7] = BITMASK_72_OF_256;
    BITMASKS[6] = BITMASK_96_OF_256;
    BITMASKS[5] = BITMASK_120_OF_256;
    BITMASKS[4] = BITMASK_144_OF_256;
    BITMASKS[3] = BITMASK_168_OF_256;
    BITMASKS[2] = BITMASK_192_OF_256;
    BITMASKS[1] = BITMASK_216_OF_256;
    BITMASKS[0] = BITMASK_240_OF_256;
  }

  function updatePriceFeeds(uint128[] calldata _updateDatas, bytes32 _encodedVaas) external onlyUpdater {
    // Loop through all of the price data
    uint256 _len = _updateDatas.length;
    if (_len == 0) return;

    for (uint256 i = 0; i < _len; ) {
      (uint16 _priceIndex, IEcoPythPriceInfo memory _newPriceInfo) = _parseUpdateData(_updateDatas[i]);
      IEcoPythPriceInfo memory _currentPriceInfo = _parsePackedPriceInfo(packedPriceInfos[_priceIndex]);

      // Update the price if the new one is more fresh
      if (_currentPriceInfo.publishTime < _newPriceInfo.publishTime) {
        // Price information is more recent than the existing price information.
        packedPriceInfos[_priceIndex] = _buildPackedPriceInfo(_newPriceInfo.publishTime, _newPriceInfo.price);
      }

      unchecked {
        ++i;
      }
    }

    emit LogVaas(_encodedVaas);
  }

  function updatePriceFeeds(bytes32[] calldata _prices, bytes32 _encodedVaas) external onlyUpdater {
    prices = _prices;

    emit LogVaas(_encodedVaas);
  }

  /// @dev Returns the current price for the given price feed ID. Revert if price never got fed.
  /// @param id The unique identifier of the price feed.
  /// @return price The current price.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    uint256 index = mapPriceIdToIndex[id] - 1;
    uint256 internalIndex = index % 10;
    uint256 word = uint256(prices[index / 10]);
    int256 priceBit = int256((word >> (256 - (24 * (internalIndex + 1)))));

    // price.publishTime = uint64(_priceInfo.publishTime);
    // price.expo = -8;
    price.price = 1 ** priceBit;
    // price.conf = 0;
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
    mapPriceIdToIndex[_assetId] = packedPriceInfosLength;
    ++packedPriceInfosLength;
  }

  /// _______________uint128_____________________
  /// __uint16__ ____uint48____ ______int64______
  ///   index   |  publishTime |     price
  function parseUpdateData(
    uint128 _updateData
  ) external pure returns (uint16 _priceIndex, IEcoPythPriceInfo memory _priceInfo) {
    return _parseUpdateData(_updateData);
  }

  function _parseUpdateData(
    uint128 _updateData
  ) internal pure returns (uint16 _priceIndex, IEcoPythPriceInfo memory _priceInfo) {
    _priceIndex = uint16((_updateData >> (128 - 16)) & BITMASK_16_OF_128);
    _priceInfo.publishTime = uint48((_updateData >> (128 - 48 - 16)) & BITMASK_48_OF_128);
    _priceInfo.price = int64(uint64((_updateData) & BITMASK_64_OF_128));
    return (_priceIndex, _priceInfo);
  }

  /// __________uint112_______________
  /// ____uint48____ ______int64______
  ///   publishTime |     price
  function parsePackedPriceInfo(uint112 _packedPriceInfo) external pure returns (IEcoPythPriceInfo memory _priceInfo) {
    return _parsePackedPriceInfo(_packedPriceInfo);
  }

  function _parsePackedPriceInfo(uint112 _packedPriceInfo) internal pure returns (IEcoPythPriceInfo memory _priceInfo) {
    _priceInfo.publishTime = uint48((_packedPriceInfo >> (112 - 48)) & BITMASK_48_OF_112);
    _priceInfo.price = int64(uint64((_packedPriceInfo) & BITMASK_64_OF_112));
    return _priceInfo;
  }

  function buildUpdateData(uint16 _priceIndex, uint48 _publishTime, int64 _price) external pure returns (uint128) {
    return _buildUpdateData(_priceIndex, _publishTime, _price);
  }

  function _buildUpdateData(uint16 _priceIndex, uint48 _publishTime, int64 _price) internal pure returns (uint128) {
    return uint128(bytes16(abi.encodePacked(_priceIndex, _publishTime, _price)));
  }

  function buildPackedPriceInfo(uint48 _publishTime, int64 _price) external pure returns (uint112) {
    return _buildPackedPriceInfo(_publishTime, _price);
  }

  function _buildPackedPriceInfo(uint48 _publishTime, int64 _price) internal pure returns (uint112) {
    return uint112(bytes14(abi.encodePacked(_publishTime, _price)));
  }
}
