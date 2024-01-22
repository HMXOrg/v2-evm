// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { TickMath } from "@aperture-finance/uni-v3-lib/TickMath.sol";

import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

import { SqrtX96Codec } from "@hmx/libraries/SqrtX96Codec.sol";

import { IPythPriceInfo, IEcoPythPriceInfo } from "@hmx/oracles/interfaces/IPyth.sol";
import { IEcoPyth3 } from "@hmx/oracles/interfaces/IEcoPyth3.sol";

contract EcoPyth3 is Ownable, IEcoPyth3 {
  using SafeCast for uint256;
  using SafeCast for int256;

  // errors
  error EcoPyth_AssetIdHasAlreadyBeenDefined();
  error EcoPyth_InvalidArgs();
  error EcoPyth_OnlyUpdater();
  error EcoPyth_PriceFeedNotFound();
  error EcoPyth_Uint32Overflow();

  // array of price data
  // it is stored as `tick` from the Uniswap tick price math
  // https://docs.uniswap.org/contracts/v3/reference/core/libraries/TickMath
  bytes32[] public prices;
  // this is the minimum publish time of every markets from the latest round of price feed
  // when we feed the prices, we will feed the diff from this `minPublishTime`.
  // the diff will be positive only
  uint256 public minPublishTime;
  // this is the array of differences value from the `minPublishTime` for each market
  // we don't store actual publish time of each price for gas optimization
  bytes32[] public publishTimeDiff;
  // map Asset Id to index in the `prices` which is the array of tick price
  mapping(bytes32 => uint256) public mapAssetIdToIndex;
  bytes32[] public assetIds;
  uint256 public indexCount;
  // each price and each publish time diff will occupy 24 bits
  // price will be in int24, where publish time diff will be in uint24
  // multiple prices/publish time diffs will be fitted into a single uint256 (or word)
  // uint256 will be able to contain 10 (10 * 24 = 240 bits) entries
  uint256 public constant MAX_PRICE_PER_WORD = 10;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdaters;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);
  event LogVaas(bytes32 _encodedVaas);
  event SetAssetId(uint256 indexed index, bytes32 assetId);

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
    // Preoccupied index 0 as any of `mapAssetIdToIndex` returns default as 0
    indexCount = 1;
    // First index is not used
    assetIds.push("0");
    // Insert ETH and BTC asset IDs to enforce their order
    _insertAssetId("ETH");
    _insertAssetId("BTC");
  }

  function getAssetIds() external view returns (bytes32[] memory) {
    return assetIds;
  }

  function updatePriceFeeds(
    bytes32[] calldata _prices,
    bytes32[] calldata _publishTimeDiff,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external onlyUpdater {
    prices = _prices;
    publishTimeDiff = _publishTimeDiff;
    minPublishTime = _minPublishTime;

    emit LogVaas(_encodedVaas);
  }

  /// @notice Returns decoded data according to the given "_wat".
  /// @dev If "_wat" is 0, then it will decode price data.
  /// @dev If "_wat" is 1, then it will decode publish time diff data.
  /// @param _wat The type of data to decode.
  /// @param _outerIndex The outer index of the data to decode.
  /// @param _innerIndex The inner index of the data to decode.
  function _decodeData(uint8 _wat, uint256 _outerIndex, uint256 _innerIndex) internal view returns (uint256) {
    if (_wat == 0) {
      uint256 _wordPrice = uint256(prices[_outerIndex]);
      int24 _tick = int24(int256((_wordPrice >> (256 - (24 * (_innerIndex + 1))))));
      uint160 _sqrtPriceX96 = TickMath.getSqrtRatioAtTick(_tick);
      return (uint256(_sqrtPriceX96) * (uint256(_sqrtPriceX96)) * (1e8)) >> (96 * 2);
    } else if (_wat == 1) {
      uint256 wordPublishTimeDiff = uint256(publishTimeDiff[_outerIndex]);
      return uint24(uint256((wordPublishTimeDiff >> (256 - (24 * (_innerIndex + 1))))));
    }
    revert EcoPyth_InvalidArgs();
  }

  function _getPriceOuterIndexZero(uint256 _assetIndex, uint256 _innerIndex) internal view returns (uint256) {
    if (_assetIndex == 0) {
      // If _assetIndex is 0 (ETH), then decode price data and return it.
      return _decodeData(0, 0, _innerIndex);
    } else if (_assetIndex == 1) {
      // If _assetIndex is 1 (BTC), then should return full price.
      // Shift right 12 bit less due to BTC uses 32 bits instead of 24 bits.
      return uint256(uint32(uint256(prices[0]) >> (256 - (24 * 2 + 12)))) * 1e6;
    } else {
      // Else need to decode with a padding as BTC price takes more bits than others.
      uint256 _wordPrice = uint256(prices[0]);
      int24 _tick = int24(int256((_wordPrice >> (256 - (24 * (_innerIndex + 1) + 12)))));
      uint160 _sqrtPriceX96 = TickMath.getSqrtRatioAtTick(_tick);
      return (uint256(_sqrtPriceX96) * (uint256(_sqrtPriceX96)) * (1e8)) >> (96 * 2);
    }
  }

  /// @dev Returns the current price for the given price feed ID. Revert if price never got fed.
  /// @param id The unique identifier of the price feed.
  /// @return price The current price.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    // Check
    if (mapAssetIdToIndex[id] == 0) revert EcoPyth_PriceFeedNotFound();

    // Find internal index of the given asset ID
    uint256 _assetIndex = mapAssetIdToIndex[id] - 1;
    uint256 _outerIndex = _assetIndex / 10;
    uint256 _innerIndex = _assetIndex % 10;
    uint256 _price;

    if (_outerIndex == 0) {
      _price = _getPriceOuterIndexZero(_assetIndex, _innerIndex);
    } else {
      _price = _decodeData(0, _outerIndex, _innerIndex);
    }

    price.publishTime = minPublishTime + _decodeData(1, _outerIndex, _innerIndex);
    price.expo = -8;
    price.price = int64(int256(_price));
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

  function setUpdaters(address[] calldata _accounts, bool[] calldata _isActives) external onlyOwner {
    if (_accounts.length != _isActives.length) revert EcoPyth_InvalidArgs();
    for (uint256 i = 0; i < _accounts.length; ) {
      // Set the `isActive` status of the given account
      isUpdaters[_accounts[i]] = _isActives[i];

      // Emit a `LogSetUpdater` event indicating the updated status of the account
      emit LogSetUpdater(_accounts[i], _isActives[i]);
      unchecked {
        ++i;
      }
    }
  }

  function insertAssetIds(bytes32[] calldata _assetIds) external onlyOwner {
    uint256 _len = _assetIds.length;
    for (uint256 i = 0; i < _len; ) {
      _insertAssetId(_assetIds[i]);

      unchecked {
        ++i;
      }
    }
  }

  function insertAssetId(bytes32 _assetId) external onlyOwner {
    _insertAssetId(_assetId);
  }

  function _insertAssetId(bytes32 _assetId) internal {
    if (mapAssetIdToIndex[_assetId] != 0) revert EcoPyth_AssetIdHasAlreadyBeenDefined();
    mapAssetIdToIndex[_assetId] = indexCount;
    emit SetAssetId(indexCount, _assetId);
    assetIds.push(_assetId);
    ++indexCount;
  }

  function setAssetId(uint256 _index, bytes32 _assetId) external onlyOwner {
    if (_index == 0) revert EcoPyth_InvalidArgs();

    mapAssetIdToIndex[_assetId] = _index;

    emit SetAssetId(_index, _assetId);

    // Reset all prices to zero,
    // this will prevent anyone from using the prices from here without another price update
    delete prices;
    delete publishTimeDiff;
    minPublishTime = 0;
  }

  /// @notice Build the price update data for the given prices.
  /// @param _priceE18s The prices to build the price update data for.
  function buildPriceUpdateData(uint256[] calldata _priceE18s) external pure returns (bytes32[] memory _updateData) {
    _updateData = new bytes32[]((_priceE18s.length + MAX_PRICE_PER_WORD - 1) / MAX_PRICE_PER_WORD);
    uint256 _outerIndex;
    uint256 _innerIndex;
    bytes32 _partialWord;
    int24 _tick;
    for (uint256 i; i < _priceE18s.length; ++i) {
      _tick = TickMath.getTickAtSqrtRatio(SqrtX96Codec.encode(_priceE18s[i]));
      _outerIndex = i / MAX_PRICE_PER_WORD;
      _innerIndex = i % MAX_PRICE_PER_WORD;
      if (_outerIndex == 0) {
        // If outer index is 0, then we to handle it differently, as BTC price is stored in full price.
        if (_innerIndex == 0) {
          // If innner index is 0, then no need to shift, as it is the first price.
          _partialWord = bytes32(uint256(uint24(_tick)) << (24 * (MAX_PRICE_PER_WORD - 1 - _innerIndex) + 16));
          _updateData[_outerIndex] |= _partialWord;
        } else if (_innerIndex == 1) {
          // If inner index is 1, then we store the full BTC price in 2 decimals.
          // We shift left 12 bits less due to normal price fit 24 bits,
          // but BTC price uses 32 bits so we need to shift 12 bits less
          uint256 _btcPrice = _priceE18s[i] / 1e16;
          if (_btcPrice > uint256(type(uint32).max)) revert EcoPyth_Uint32Overflow();
          _partialWord = bytes32(_btcPrice << (24 * 8 - 12 + 16));
          _updateData[_outerIndex] |= _partialWord;
        } else {
          // If inner index is not 0 or 1, then we need to shift 12 bits less due to BTC price uses 32 bits.
          _partialWord = bytes32(uint256(uint24(_tick)) << (24 * (MAX_PRICE_PER_WORD - 1 - _innerIndex) + 16 - 12));
          _updateData[_outerIndex] |= _partialWord;
        }
      } else {
        _partialWord = bytes32(uint256(uint24(_tick)) << (24 * (MAX_PRICE_PER_WORD - 1 - _innerIndex) + 16));
        _updateData[_outerIndex] |= _partialWord;
      }
    }
  }

  function buildPublishTimeUpdateData(
    uint24[] calldata _publishTimeDiff
  ) external pure returns (bytes32[] memory _updateData) {
    _updateData = new bytes32[]((_publishTimeDiff.length + MAX_PRICE_PER_WORD - 1) / MAX_PRICE_PER_WORD);
    for (uint256 i; i < _publishTimeDiff.length; ++i) {
      uint256 outerIndex = i / MAX_PRICE_PER_WORD;
      uint256 innerIndex = i % MAX_PRICE_PER_WORD;
      bytes32 partialWord = bytes32(uint256(_publishTimeDiff[i]) << (24 * (MAX_PRICE_PER_WORD - 1 - innerIndex) + 16));
      _updateData[outerIndex] |= partialWord;
    }
  }
}
