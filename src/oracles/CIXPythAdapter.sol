// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ABDKMath64x64 } from "@hmx/libraries/ABDKMath64x64.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { ICIXPythAdapter } from "./interfaces/ICIXPythAdapter.sol";
import { IReadablePyth } from "./interfaces/IReadablePyth.sol";

/// @dev Customized Index Pyth Adapter - Index price will be calculated using geometric mean according to weight config
contract CIXPythAdapter is OwnableUpgradeable, ICIXPythAdapter {
  using ABDKMath64x64 for int128;

  // constant
  int128 immutable E8_PRECISION_64x64 = ABDKMath64x64.fromUInt(1e8);

  // errors
  error CIXPythAdapter_BrokenPythPrice();
  error CIXPythAdapter_UnknownAssetId();
  error CIXPythAdapter_BadParams();
  error CIXPythAdapter_BadWeightSum();

  // state variables
  IReadablePyth public pyth;
  // mapping of our asset id to Pyth's price id
  mapping(bytes32 assetId => ICIXPythAdapter.CIXPythPriceConfig config) public configs;

  // events
  event LogSetConfig(bytes32 indexed _assetId, uint256 _cE8, bytes32[] _pythPriceIds, uint256[] _weightsE8);
  event LogSetPyth(address _oldPyth, address _newPyth);

  function initialize(address _pyth) external initializer {
    OwnableUpgradeable.__Ownable_init();

    pyth = IReadablePyth(_pyth);
  }

  /// @notice convert Pyth's price to uint256.
  /// @dev This is partially taken from https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/examples/oracle_swap/contract/src/OracleSwap.sol#L92
  /// @param _priceStruct The Pyth's price struct to convert.
  /// @param _targetDecimals The target decimals to convert to.
  function _convertToUint256(
    PythStructs.Price memory _priceStruct,
    uint8 _targetDecimals
  ) private pure returns (uint256) {
    if (_priceStruct.price <= 0 || _priceStruct.expo > 0 || _priceStruct.expo < -255) {
      revert CIXPythAdapter_BrokenPythPrice();
    }

    uint8 _priceDecimals = uint8(uint32(-1 * _priceStruct.expo));

    uint64 _price = uint64(_priceStruct.price);

    uint256 _price256;
    if (_targetDecimals - _priceDecimals >= 0) {
      _price256 = uint256(_price) * 10 ** uint32(_targetDecimals - _priceDecimals);
    } else {
      _price256 = uint256(_price) / 10 ** uint32(_priceDecimals - _targetDecimals);
    }

    return _price256;
  }

  /// @notice Calculate geometric average price according to the formula
  /// price = c * (price1 ^ weight1) * (price2 ^ weight2) * ... * (priceN ^ weightN)
  /// @dev The function returns the average price of given prices and weight in e30 basis
  /// @param _cE8 A magic constant in e8 basis
  /// @param _pricesE8 An array of prices in e8 basis
  /// @param _weightsE8 An array of price weights in e8 basis, the lenght should be relative to _pricesE8
  function _calculateGeometricAveragePriceE30(
    uint256 _cE8,
    uint256[] memory _pricesE8,
    uint256[] memory _weightsE8
  ) private view returns (uint256 _avgE30) {
    // Declare _accum as c
    int128 _accum = _convertE8To64x64(_cE8);

    // Reducing the _pricesE8, _weightsE8 with multiplication onto _accum
    uint256 _len = _pricesE8.length;
    for (uint256 i = 0; i < _len; ) {
      int128 _price = _convertE8To64x64(_pricesE8[i]);
      int128 _weight = _convertE8To64x64(_weightsE8[i]);

      _accum = _accum.mul(_price.pow(_weight));

      unchecked {
        ++i;
      }
    }

    // Convert the final result to uint256 in e30 basis
    _avgE30 = _convert64x64ToE8(_accum) * 1e22;
    return _avgE30;
  }

  function _convertE8To64x64(uint256 _n) private view returns (int128 _output) {
    _output = ABDKMath64x64.fromUInt(_n).div(E8_PRECISION_64x64);
    return _output;
  }

  function _convert64x64ToE8(int128 _n) private view returns (uint128 _output) {
    _output = _n.mul(E8_PRECISION_64x64).toUInt();
    return _output;
  }

  /**
   * Getter
   */
  /// @notice Get the latest price of the given asset. Returned price is in e30 basis.
  /// @dev The price returns here can be staled. Min publish time is picked from the oldest price.
  /// @param _assetId The HMX asset id to get price. (not Pyth priceId)
  function getLatestPrice(
    bytes32 _assetId,
    bool /* _isMax */,
    uint32 /* _confidenceThreshold */
  ) external view returns (uint256 _price30, uint256 _publishTime) {
    // 1. Load the config
    ICIXPythAdapter.CIXPythPriceConfig memory _config = configs[_assetId];

    uint256 _len = _config.pythPriceIds.length;
    if (_len == 0) revert CIXPythAdapter_UnknownAssetId();

    // 2. Prepare the parameters, map them into arrays
    uint256[] memory _pricesE8 = new uint256[](_len);
    uint256[] memory _weightsE8 = new uint256[](_len);

    for (uint256 i = 0; i < _len; ) {
      // Get price
      PythStructs.Price memory _price = pyth.getPriceUnsafe(_config.pythPriceIds[i]);

      // Store params in array for average calculation
      _pricesE8[i] = _convertToUint256(_price, 8);
      _weightsE8[i] = _config.weightsE8[i];

      // Update publish time, with minimum _price.publishTime
      if (i == 0) {
        _publishTime = _price.publishTime;
      } else {
        _publishTime = HMXLib.min(_publishTime, _price.publishTime);
      }

      unchecked {
        ++i;
      }
    }

    // 3. Calculate the price with geometric weighted average
    _price30 = _calculateGeometricAveragePriceE30(_config.cE8, _pricesE8, _weightsE8);

    return (_price30, _publishTime);
  }

  function getConfigByAssetId(bytes32 _assetId) external view returns (ICIXPythAdapter.CIXPythPriceConfig memory) {
    return configs[_assetId];
  }

  /**
   * Setter
   */
  /// @notice Set new Pyth contract address.
  /// @param _newPyth New Pyth contract address.
  function setPyth(address _newPyth) external onlyOwner {
    emit LogSetPyth(address(pyth), _newPyth);
    pyth = IReadablePyth(_newPyth);
  }

  /// @notice Set the Pyth price id for the given asset.
  /// @param _assetId The HMX asset id to set. (not Pyth priceId)
  /// @param _cE8 A magic constant. Need to be recalculate every time the weight is changed.
  /// @param _pythPriceIds An array of pythPriceIds. This should be relative to _weightsE8.
  /// @param _weightsE8 An array of weights of certain asset in e8 basis. This should be relative to _pythPriceIds.
  function setConfig(
    bytes32 _assetId,
    uint256 _cE8,
    bytes32[] memory _pythPriceIds,
    uint256[] memory _weightsE8
  ) external onlyOwner {
    ICIXPythAdapter.CIXPythPriceConfig memory _config;
    uint256 _weightSum;

    // 0. Validate params
    uint256 _len = _pythPriceIds.length;
    if (_len != _weightsE8.length) revert CIXPythAdapter_BadParams();
    if (_cE8 == 0) revert CIXPythAdapter_BadParams();

    // 1. Assign c
    _config.cE8 = _cE8;

    // 2. Assign weight config
    // _config.weightConfigs = new WeightConfig[](_len);
    for (uint256 i = 0; i < _len; ) {
      // Assign each field on weight config
      _config.pythPriceIds[i] = _pythPriceIds[i];
      _config.weightsE8[i] = _weightsE8[i];

      // Accum weight sum for later check
      _weightSum += _weightsE8[i];
      unchecked {
        ++i;
      }
    }

    // 3. Validate weight sum
    if (_weightSum != 1e8) revert CIXPythAdapter_BadWeightSum();

    // 4. Save to storage
    configs[_assetId] = _config;
    emit LogSetConfig(_assetId, _cE8, _pythPriceIds, _weightsE8);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
