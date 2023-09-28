// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { TickMath } from "@aperture-finance/uni-v3-lib/TickMath.sol";

contract OrderbookOracle is Ownable {
  using SafeCast for uint256;
  using SafeCast for int256;

  // errors
  error OrderbookOracle_OnlyUpdater();
  error OrderbookOracle_InvalidArgs();
  error OrderbookOracle_MarketIndexHasAlreadyBeenDefined();
  error OrderbookOracle_PriceFeedNotFound();

  // array of 1% orderbook depth data from CEX
  // it is stored as `tick` from the Uniswap tick price math
  // https://docs.uniswap.org/contracts/v3/reference/core/libraries/TickMath
  // the order of the data will be according to market index
  bytes32[] public askDepths;
  bytes32[] public bidDepths;
  bytes32[] public coeffVariants; // C (coefficient variant) = sd / averagePrice
  // map Asset Id to index in the `prices` which is the array of tick price
  mapping(uint256 => uint256) public mapMarketIndexToIndex;
  uint256[] public marketIndexes;
  uint256 public indexCount;
  // each price and each publish time diff will occupy 24 bits
  // price will be in int24, where publish time diff will be in uint24
  // multiple prices/publish time diffs will be fitted into a single uint256 (or word)
  // uint256 will be able to contain 10 (10 * 24 = 240 bits) entries
  uint256 public constant MAX_DEPTH_PER_WORD = 10;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdaters;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);
  event SetMarketIndex(uint256 indexed index, uint256 marketIndex);

  /**
   * Modifiers
   */
  modifier onlyUpdater() {
    if (!isUpdaters[msg.sender]) {
      revert OrderbookOracle_OnlyUpdater();
    }
    _;
  }

  constructor() {
    // Preoccupied index 0 as any of `mapMarketIndexToIndex` returns default as 0
    indexCount = 1;
    // First index is not used
    marketIndexes.push(type(uint256).max);
  }

  function getMarketIndexes() external view returns (uint256[] memory) {
    return marketIndexes;
  }

  function updateData(
    bytes32[] calldata _askDepths,
    bytes32[] calldata _bidDepths,
    bytes32[] calldata _coeffVariants
  ) external onlyUpdater {
    askDepths = _askDepths;
    bidDepths = _bidDepths;
    coeffVariants = _coeffVariants;
  }

  function getData(
    uint256 marketIndex
  ) external view returns (uint256 askDepth, uint256 bidDepth, uint256 coeffVariant) {
    if (mapMarketIndexToIndex[marketIndex] == 0) revert OrderbookOracle_PriceFeedNotFound();
    uint256 index = mapMarketIndexToIndex[marketIndex] - 1;
    uint256 internalIndex = index % 10;

    int24 askDepthTick = int24(int256((uint256(askDepths[index / 10]) >> (256 - (24 * (internalIndex + 1))))));
    uint160 sqrtAskDepthX96 = TickMath.getSqrtRatioAtTick(askDepthTick);
    askDepth = (uint256(sqrtAskDepthX96) * (uint256(sqrtAskDepthX96)) * (1e8)) >> (96 * 2);

    int24 bidDepthTick = int24(int256((uint256(bidDepths[index / 10]) >> (256 - (24 * (internalIndex + 1))))));
    uint160 sqrtBidDepthX96 = TickMath.getSqrtRatioAtTick(bidDepthTick);
    bidDepth = (uint256(sqrtBidDepthX96) * (uint256(sqrtBidDepthX96)) * (1e8)) >> (96 * 2);

    int24 coeffVariantTick = int24(int256((uint256(coeffVariants[index / 10]) >> (256 - (24 * (internalIndex + 1))))));
    uint160 sqrtCoeffVariantX96 = TickMath.getSqrtRatioAtTick(coeffVariantTick);
    coeffVariant = (uint256(sqrtCoeffVariantX96) * (uint256(sqrtCoeffVariantX96)) * (1e8)) >> (96 * 2);
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
    if (_accounts.length != _isActives.length) revert OrderbookOracle_InvalidArgs();
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

  function insertMarketIndexes(uint256[] calldata _marketIndexes) external onlyOwner {
    uint256 _len = _marketIndexes.length;
    for (uint256 i = 0; i < _len; ) {
      _insertMarketIndex(_marketIndexes[i]);

      unchecked {
        ++i;
      }
    }
  }

  function insertMarketIndex(uint256 _marketIndex) external onlyOwner {
    _insertMarketIndex(_marketIndex);
  }

  function _insertMarketIndex(uint256 _marketIndex) internal {
    if (mapMarketIndexToIndex[_marketIndex] != 0) revert OrderbookOracle_MarketIndexHasAlreadyBeenDefined();
    mapMarketIndexToIndex[_marketIndex] = indexCount;
    emit SetMarketIndex(indexCount, _marketIndex);
    marketIndexes.push(_marketIndex);
    ++indexCount;
  }

  function buildUpdateData(int24[] calldata _depths) external pure returns (bytes32[] memory _updateData) {
    _updateData = new bytes32[]((_depths.length + MAX_DEPTH_PER_WORD - 1) / MAX_DEPTH_PER_WORD);
    for (uint256 i; i < _depths.length; ++i) {
      uint256 outerIndex = i / MAX_DEPTH_PER_WORD;
      uint256 innerIndex = i % MAX_DEPTH_PER_WORD;
      bytes32 partialWord = bytes32(uint256(uint24(_depths[i])) << (24 * (MAX_DEPTH_PER_WORD - 1 - innerIndex) + 16));
      _updateData[outerIndex] |= partialWord;
    }
  }
}
