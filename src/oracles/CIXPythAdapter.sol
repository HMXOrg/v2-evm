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
  mapping(bytes32 assetId => ICIXPythAdapter.CIXPythPriceConfig config) public configs;

  // events
  event LogSetConfig(
    bytes32 indexed _assetId,
    uint256 _cE8,
    bytes32[] _pythPriceIds,
    uint256[] _weightsE8,
    bool[] _usdQuoteds
  );
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

  function _accumulateWeightedPrice(
    int128 _accum,
    uint256 _priceE8,
    uint256 _weightE8,
    bool _usdQuoted
  ) private view returns (int128) {
    int128 _price = _convertE8To64x64(_priceE8);
    int128 _weight = _convertE8To64x64(_weightE8);
    if (_usdQuoted) _weight = _weight.neg();

    return _accum.mul(_price.pow(_weight));
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
  ) external view returns (uint256 _priceE30, uint256 _publishTime) {
    // 1. Load the config
    ICIXPythAdapter.CIXPythPriceConfig memory _config = configs[_assetId];

    uint256 _len = _config.pythPriceIds.length;
    if (_len == 0) revert CIXPythAdapter_UnknownAssetId();

    // 2. Loop through config.
    // - Reduce the parameter with geometric average calculation.
    //   Calculate geometric average price according to the formula
    //   price = c * (price1 ^ +-weight1) * (price2 ^ +-weight2) * ... * (priceN ^ +-weightN)
    // - Keep track of minimum publish time

    // Declare _accum as c
    int128 _accum = _convertE8To64x64(_config.cE8);

    for (uint256 i = 0; i < _len; ) {
      // Get price from Pyth
      PythStructs.Price memory _priceStruct = pyth.getPriceUnsafe(_config.pythPriceIds[i]);
      uint256 _priceE8 = _convertToUint256(_priceStruct, 8);

      // Accumulate the _accum with (priceN ^ +-weightN)
      _accum = _accumulateWeightedPrice(_accum, _priceE8, _config.weightsE8[i], _config.usdQuoteds[i]);

      // Update publish time, with minimum _price.publishTime
      if (i == 0) {
        _publishTime = _priceStruct.publishTime;
      } else {
        _publishTime = HMXLib.min(_publishTime, _priceStruct.publishTime);
      }

      unchecked {
        ++i;
      }
    }

    // 3. Convert the final result to uint256 in e30 basis
    _priceE30 = _convert64x64ToE8(_accum) * 1e22;

    return (_priceE30, _publishTime);
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
    uint256[] memory _weightsE8,
    bool[] memory _usdQuoteds
  ) external onlyOwner {
    ICIXPythAdapter.CIXPythPriceConfig memory _config;

    // 1. Validate params

    uint256 _len = _pythPriceIds.length;
    // Validate length
    {
      if (_len != _weightsE8.length || _len != _usdQuoteds.length) revert CIXPythAdapter_BadParams();
      if (_cE8 == 0) revert CIXPythAdapter_BadParams();
    }

    // Validate weight and price id
    {
      uint256 _weightSum;
      for (uint256 i = 0; i < _len; ) {
        // Accum weight sum
        _weightSum += _weightsE8[i];

        // Sanity check for price id
        pyth.getPriceUnsafe(_pythPriceIds[i]);

        unchecked {
          ++i;
        }
      }

      if (_weightSum != 1e8) revert CIXPythAdapter_BadWeightSum();
    }

    // 2. Assign configs
    _config.cE8 = _cE8;
    _config.pythPriceIds = _pythPriceIds;
    _config.weightsE8 = _weightsE8;
    _config.usdQuoteds = _usdQuoteds;

    // 3. Save to storage
    configs[_assetId] = _config;
    emit LogSetConfig(_assetId, _cE8, _pythPriceIds, _weightsE8, _usdQuoteds);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
