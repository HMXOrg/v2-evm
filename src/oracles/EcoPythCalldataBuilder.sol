// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// deps
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

// interfaces
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

// libs
import { SqrtX96Codec } from "@hmx/libraries/SqrtX96Codec.sol";
import { PythLib } from "@hmx/libraries/PythLib.sol";
import { TickMath } from "@hmx/libraries/TickMath.sol";

contract EcoPythCalldataBuilder is IEcoPythCalldataBuilder {
  IEcoPyth public ecoPyth;

  constructor(IEcoPyth ecoPyth_) {
    ecoPyth = ecoPyth_;
  }

  function isOverMaxDiff(bytes32 _assetId, int64 _price, uint32 _maxDiffBps) internal view returns (bool) {
    PythStructs.Price memory _ecoPythPrice = ecoPyth.getPriceUnsafe(_assetId);
    if (_ecoPythPrice.price * 10000 > _price * int32(_maxDiffBps)) {
      return true;
    }
    if (_ecoPythPrice.price * int32(_maxDiffBps) < _price * 10000) {
      return true;
    }
    return false;
  }

  function build(
    BuildData[] calldata _data
  )
    external
    view
    returns (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    )
  {
    _minPublishTime = type(uint256).max;
    for (uint _i = 0; _i < _data.length; ) {
      // Check if price vs last price on EcoPyth is not over max diff
      require(!isOverMaxDiff(_data[_i].assetId, _data[_i].priceE8, _data[_i].maxDiffBps), "OVER_DIFF");

      // Find the minimum publish time
      if (_data[_i].publishTime < _minPublishTime) {
        _minPublishTime = _data[_i].publishTime;
      }
      unchecked {
        ++_i;
      }
    }

    // Build ticks and publish time diffs
    int24[] memory _ticks = new int24[](_data.length);
    uint24[] memory _publishTimeDiffs = new uint24[](_data.length);
    for (uint _i = 0; _i < _data.length; ) {
      // Build the price update calldata
      _ticks[_i] = TickMath.getTickAtSqrtRatio(SqrtX96Codec.encode(PythLib.convertToUint(_data[_i].priceE8, -8, 18)));
      _publishTimeDiffs[_i] = uint24(_data[_i].publishTime - _minPublishTime);

      unchecked {
        ++_i;
      }
    }

    // Build the priceUpdateCalldata
    _priceUpdateCalldata = ecoPyth.buildPriceUpdateData(_ticks);
    // Build the publishTimeUpdateCalldata
    _publishTimeUpdateCalldata = ecoPyth.buildPublishTimeUpdateData(_publishTimeDiffs);
  }
}
