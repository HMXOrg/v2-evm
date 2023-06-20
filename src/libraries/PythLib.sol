// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

library PythLib {
  function convertToUint(int64 _price, int8 _expo, uint8 _targetDecimals) internal pure returns (uint256) {
    if (_price < 0 || _expo > 0 || _expo < -255) {
      revert();
    }

    uint8 _priceDecimals = uint8(uint32(int32(-1 * _expo)));

    if (_targetDecimals - _priceDecimals >= 0) {
      return uint(uint64(_price)) * 10 ** uint32(_targetDecimals - _priceDecimals);
    } else {
      return uint(uint64(_price)) / 10 ** uint32(_priceDecimals - _targetDecimals);
    }
  }
}
