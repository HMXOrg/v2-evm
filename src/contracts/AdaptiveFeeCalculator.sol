// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ABDKMath64x64 } from "@hmx/libraries/ABDKMath64x64.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

contract AdaptiveFeeCalculator {
  using ABDKMath64x64 for int128;

  int128 RATE_PRECISION_64x64 = ABDKMath64x64.fromUInt(1e8);
  int128 BPS_PRECISION_64x64 = ABDKMath64x64.fromUInt(1e4);

  function getAdaptiveFeeBps(
    uint256 positionSize,
    uint256 epochOI,
    uint256 orderbookDepth,
    uint256 standardDeviationE8,
    uint256 averagePriceE8,
    uint256 baseFeeBps,
    uint256 maxFeeBps
  ) external view returns (uint256 feeBps) {
    // Normalize the formula for easier coding
    // y = 0.0007 + ((min(x/d, 1))^g) * 0.05
    // y = 0.0007 + ((min(A, 1))^g) * 0.05
    // y = 0.0007 + (B^g) * 0.05
    // y = 0.0007 + C * 0.05
    int128 x = _convertE8To64x64(positionSize + epochOI);
    int128 d = _convertE8To64x64(orderbookDepth);
    int128 A = x.div(d);

    int128 g = findG(findC(standardDeviationE8, averagePriceE8));
    int128 B = _min(A, ABDKMath64x64.fromUInt(1));
    int128 C = B.pow(g);
    int128 y = _convertE8To64x64(baseFeeBps * 1e4).add(C.mul(_convertE8To64x64(maxFeeBps * 1e4)));
    return HMXLib.min(ABDKMath64x64.toUInt(ABDKMath64x64.mul(y, BPS_PRECISION_64x64)), uint256(maxFeeBps));
  }

  function findG(int128 c) public pure returns (int128 g) {
    // g = 2^(2 - min(1, c/100))
    int128 c_100 = c.div(ABDKMath64x64.fromUInt(100));
    int128 min = _min(ABDKMath64x64.fromUInt(1), c_100);
    int128 expo = ABDKMath64x64.fromUInt(2).sub(min);
    g = ABDKMath64x64.exp_2(expo);
  }

  function findC(uint256 standardDeviationE8, uint256 averagePriceE8) public view returns (int128 c) {
    // c = s/p
    int128 s = _convertE8To64x64(standardDeviationE8);
    int128 p = _convertE8To64x64(averagePriceE8);

    c = s.div(p);
  }

  function _convertE8To64x64(uint256 input) internal view returns (int128 output) {
    output = ABDKMath64x64.fromUInt(input).div(RATE_PRECISION_64x64);
  }

  function _min(int128 a, int128 b) internal pure returns (int128) {
    return a < b ? a : b;
  }
}
