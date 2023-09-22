// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest, console2 } from "@hmx-test/base/BaseTest.sol";
import { ABDKMath64x64 } from "@hmx/libraries/ABDKMath64x64.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

contract AdaptiveSpreadMath_Test is BaseTest {
  int128 RATE_PRECISION_64x64 = ABDKMath64x64.fromUInt(1e8);

  function test_exponential_fraction() external {
    // console2.log(ABDKMath64x64.exp_2(0x20000000000000000));
    // console2.log(ABDKMath64x64.fromUInt(1 * 10 ** 16));
    // console2.log(ABDKMath64x64.toInt(ABDKMath64x64.fromUInt(11.1 * 10 ** 16)));

    uint256 s = 0.9 * 1e8;
    uint256 p = 0.5372 * 1e8;
    uint256 size = 100_000 * 1e8;
    uint256 depth = 1_000_000 * 1e8;
    int128 baseFee = ABDKMath64x64.div(ABDKMath64x64.fromUInt(0.0007 * 1e8), RATE_PRECISION_64x64);

    int128 c = ABDKMath64x64.div(ABDKMath64x64.fromUInt(s), ABDKMath64x64.fromUInt(p)); // 0.9 / 0.5372 = 1.67535369
    humanReadable(c);
    int128 expo_of_g = ABDKMath64x64.sub(ABDKMath64x64.fromUInt(2), ABDKMath64x64.div(c, ABDKMath64x64.fromUInt(100))); // 2 - (c/100)
    int128 g = ABDKMath64x64.exp_2(expo_of_g);
    humanReadable(g);

    int128 sizeOverDepth = ABDKMath64x64.div(
      ABDKMath64x64.fromUInt(HMXLib.min((size * 1e8) / depth, 1e8)),
      RATE_PRECISION_64x64
    );
    humanReadable(
      ABDKMath64x64.mul(
        ABDKMath64x64.pow(sizeOverDepth, g),
        ABDKMath64x64.div(ABDKMath64x64.fromUInt(0.9993 * 1e8), RATE_PRECISION_64x64)
      )
    );

    int128 fee_64x64 = ABDKMath64x64.add(
      baseFee,
      ABDKMath64x64.mul(
        ABDKMath64x64.pow(sizeOverDepth, g),
        ABDKMath64x64.div(ABDKMath64x64.fromUInt(0.9993 * 1e8), RATE_PRECISION_64x64)
      )
    );
    humanReadable(fee_64x64);
  }

  function humanReadable(int128 x) internal {
    console2.log(ABDKMath64x64.toUInt(ABDKMath64x64.mul(x, RATE_PRECISION_64x64)));
  }
}
