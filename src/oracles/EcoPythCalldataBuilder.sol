// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

contract EcoPythCalldataBuilder {
  IEcoPyth public ecoPyth;

  constructor(IEcoPyth ecoPyth_) {
    ecoPyth = ecoPyth_;
  }

  struct BuildData {
    bytes32 assetId;
    int64 price;
    int8 expo;
    uint160 publishTime;
    uint24 maxDiffBps;
  }

  function isOverMaxDiff(bytes32 _assetId, int64 _price, uint24 _maxDiffBps) internal view returns (bool) {
    PythStructs.Price memory _ecoPythPrice = ecoPyth.getPriceUnsafe(_assetId);
    if (_ecoPythPrice.price * 10000 >= _price * int24(_maxDiffBps)) {
      return true;
    }
    if (_ecoPythPrice.price * int24(_maxDiffBps) <= _price * 10000) {
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
      uint160 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    )
  {
    _minPublishTime = type(uint160).max;
    for (uint _i = 0; _i < _data.length; ) {
      // Check if price vs last price on EcoPyth is not over max diff
      require(!isOverMaxDiff(_data[_i].assetId, _data[_i].price, _data[_i].maxDiffBps), "OVER_DIFF");

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
      _ticks[_i] = int24(_data[_i].price);

      unchecked {
        ++_i;
      }
    }
  }
}
