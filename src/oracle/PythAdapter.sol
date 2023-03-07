// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { IPyth, PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";
import { IPythAdapter } from "./interfaces/IPythAdapter.sol";

contract PythAdapter is Owned, IOracleAdapter, IPythAdapter {
  // errors
  error PythAdapter_BrokenPythPrice();
  error PythAdapter_ConfidenceRatioTooHigh();
  error PythAdapter_OnlyUpdater();
  error PythAdapter_UnknownAssetId();

  // state variables
  IPyth public pyth;
  // mapping of our asset id to Pyth's price id
  mapping(bytes32 => bytes32) public pythPriceIdOf;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdater;

  // events
  event SetPythPriceId(bytes32 indexed _assetId, bytes32 _prevPythPriceId, bytes32 _pythPriceId);
  event SetUpdater(address indexed _account, bool _isActive);

  constructor(IPyth _pyth) {
    pyth = _pyth;

    // Sanity
    pyth.getValidTimePeriod();
  }

  /// @notice Set the Pyth price id for the given asset.
  /// @param _assetId The asset address to set.
  /// @param _pythPriceId The Pyth price id to set.
  function setPythPriceId(bytes32 _assetId, bytes32 _pythPriceId) external onlyOwner {
    emit SetPythPriceId(_assetId, pythPriceIdOf[_assetId], _pythPriceId);
    pythPriceIdOf[_assetId] = _pythPriceId;
  }

  /// @notice convert Pyth's price to uint256.
  /// @dev This is partially taken from https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/examples/oracle_swap/contract/src/OracleSwap.sol#L92
  /// @param _priceStruct The Pyth's price struct to convert.
  /// @param _isMax Whether to use the max price or min price.
  /// @param _targetDecimals The target decimals to convert to.
  function _convertToUint256(
    PythStructs.Price memory _priceStruct,
    bool _isMax,
    uint8 _targetDecimals
  ) private pure returns (uint256) {
    if (_priceStruct.price <= 0 || _priceStruct.expo > 0 || _priceStruct.expo < -255) {
      revert PythAdapter_BrokenPythPrice();
    }

    uint8 _priceDecimals = uint8(uint32(-1 * _priceStruct.expo));
    uint64 _price = _isMax
      ? uint64(_priceStruct.price) + _priceStruct.conf
      : uint64(_priceStruct.price) - _priceStruct.conf;

    if (_targetDecimals - _priceDecimals >= 0) {
      return uint256(_price) * 10 ** uint32(_targetDecimals - _priceDecimals);
    } else {
      return uint256(_price) / 10 ** uint32(_priceDecimals - _targetDecimals);
    }
  }

  /// @notice Validate Pyth's confidence with given threshold. Revert if confidence ratio is too high.
  /// @dev To bypass the confidence check, the user can submit threshold = 1 ether
  /// @param _priceStruct The Pyth's price struct to convert.
  /// @param _confidenceThreshold The acceptable threshold confidence ratio. ex. _confidenceRatio = 0.01 ether means 1%
  function _validateConfidence(PythStructs.Price memory _priceStruct, uint32 _confidenceThreshold) private pure {
    if (_priceStruct.price < 0) revert PythAdapter_BrokenPythPrice();

    // Revert if confidence ratio is too high
    if (_priceStruct.conf * 1e6 > _confidenceThreshold * uint64(_priceStruct.price))
      revert PythAdapter_ConfidenceRatioTooHigh();
  }

  /// @notice Get the latest price of the given asset. Returned price is in 30 decimals.
  /// @dev The price returns here can be staled.
  /// @param _assetId The asset id to get price.
  /// @param _isMax Whether to get the max price.
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint32 _confidenceThreshold
  ) external view returns (uint256, int32, uint256) {
    // SLOAD
    bytes32 _pythPriceId = pythPriceIdOf[_assetId];
    if (_pythPriceId == bytes32(0)) revert PythAdapter_UnknownAssetId();
    PythStructs.Price memory _price = pyth.getPriceUnsafe(_pythPriceId);
    _validateConfidence(_price, _confidenceThreshold);

    return (_convertToUint256(_price, _isMax, 30), _price.expo, _price.publishTime);
  }
}
