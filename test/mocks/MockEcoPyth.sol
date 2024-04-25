// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { TickMath } from "@aperture-finance/uni-v3-lib/TickMath.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { IPythPriceInfo, IEcoPythPriceInfo } from "@hmx/oracles/interfaces/IPyth.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

/// @title MockEcoPyth - Keeps the same storage layout as EcoPyth
/// but allows to override prices for testing purpose.
contract MockEcoPyth is Ownable, IEcoPyth {
  using SafeCast for uint256;
  using SafeCast for int256;

  // errors
  error EcoPyth_OnlyUpdater();
  error EcoPyth_PriceFeedNotFound();
  error EcoPyth_AssetIdHasAlreadyBeenDefined();
  error EcoPyth_InvalidArgs();

  // real states
  bytes32[] public prices;
  uint256 public minPublishTime;
  bytes32[] public publishTimeDiff;
  mapping(bytes32 => uint256) public mapAssetIdToIndex;
  bytes32[] public assetIds;
  uint256 public indexCount;
  uint256 public constant MAX_PRICE_PER_WORD = 10;
  mapping(address => bool) public isUpdaters;

  // Extended mock states
  mapping(bytes32 => uint256) public overridePrices;

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
  }

  function getAssetIds() external view returns (bytes32[] memory) {
    return assetIds;
  }

  /// @notice Override price for testing purpose
  /// @param assetId Asset ID
  /// @param price Price to override
  function overridePrice(bytes32 assetId, uint256 price) external {
    overridePrices[assetId] = price;
  }

  /// @notice Return latestest price info.
  /// @dev Use for testing purpose only.
  function getLastestPriceUpdateData() external view returns (bytes32[] memory, bytes32[] memory, uint256, bytes32) {
    return (prices, publishTimeDiff, minPublishTime, "0");
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

  /// @notice Modified getPriceUnsafe. Return overridden price if it exists.
  /// @dev Use for testing purpose only.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    if (mapAssetIdToIndex[id] == 0) revert EcoPyth_PriceFeedNotFound();

    if (overridePrices[id] != 0) {
      price.publishTime = uint64(block.timestamp);
      price.expo = -8;
      price.price = int64(int256(overridePrices[id]));
      price.conf = 0;
      return price;
    }

    uint256 index = mapAssetIdToIndex[id] - 1;
    uint256 internalIndex = index % 10;
    uint256 wordPrice = uint256(prices[index / 10]);
    int24 tick = int24(int256((wordPrice >> (256 - (24 * (internalIndex + 1))))));
    uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    uint256 spotPrice = (uint256(sqrtPriceX96) * (uint256(sqrtPriceX96)) * (1e8)) >> (96 * 2);

    uint256 wordPublishTimeDiff = uint256(publishTimeDiff[index / 10]);
    uint256 diff = uint24(uint256((wordPublishTimeDiff >> (256 - (24 * (internalIndex + 1))))));

    price.publishTime = minPublishTime + diff;
    price.expo = -8;
    price.price = int64(int256(spotPrice));
    price.conf = 0;
    return price;
  }

  function getUpdateFee(bytes[] calldata /*updateData*/) external pure returns (uint feeAmount) {
    // The update fee is always 0, so simply return 0
    return 0;
  }

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

    delete prices;
    delete publishTimeDiff;
    minPublishTime = 0;
  }

  function buildPriceUpdateData(int24[] calldata _prices) external pure returns (bytes32[] memory _updateData) {
    _updateData = new bytes32[]((_prices.length + MAX_PRICE_PER_WORD - 1) / MAX_PRICE_PER_WORD);
    for (uint256 i; i < _prices.length; ++i) {
      uint256 outerIndex = i / MAX_PRICE_PER_WORD;
      uint256 innerIndex = i % MAX_PRICE_PER_WORD;
      bytes32 partialWord = bytes32(uint256(uint24(_prices[i])) << (24 * (MAX_PRICE_PER_WORD - 1 - innerIndex) + 16));
      _updateData[outerIndex] |= partialWord;
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
