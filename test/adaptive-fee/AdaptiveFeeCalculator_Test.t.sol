// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest, console2 } from "@hmx-test/base/BaseTest.sol";
import { ABDKMath64x64 } from "@hmx/libraries/ABDKMath64x64.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { AdaptiveFeeCalculator } from "@hmx/contracts/AdaptiveFeeCalculator.sol";

contract AdaptiveFeeCalculator_Test is BaseTest {
  int128 RATE_PRECISION_64x64 = ABDKMath64x64.fromUInt(1e8);
  AdaptiveFeeCalculator adaptiveFeeCalculator;

  function setUp() external {
    adaptiveFeeCalculator = new AdaptiveFeeCalculator();
  }

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

  function humanReadable(int128 x) internal view returns (uint256 result) {
    result = ABDKMath64x64.toUInt(ABDKMath64x64.mul(x, RATE_PRECISION_64x64));
    console2.log(result);
  }

  function testCorrectness() external {
    uint256 standardDeviationE8 = 0.9 * 1e8;
    uint256 averagePriceE8 = 0.5372 * 1e8;
    // 0.9 / 0.4372 = 1.67535368
    int128 c = adaptiveFeeCalculator.findC(standardDeviationE8, averagePriceE8);
    assertEq(humanReadable(c), 167535368);

    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 0.01675354))
    // g = 2^(2 - 0.01675354)
    // g = 2^(1.98324646) = 3.95381799
    int128 g = adaptiveFeeCalculator.findG(c);
    assertEq(humanReadable(g), 395381799);

    // c = sd / p
    // c = 2.56 / 0.5373 = 4.76456356
    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 4.76456356/100)) = 3.87005578
    // y = 0.0007 + ((min(400_000/500_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(400_000/500_000, 1))^3.87005578) * 0.05
    // y = 0.0007 + (0.8)^3.87005578) * 0.05
    // y = 0.0007 + 0.42165072 * 0.05
    // y = 0.02178254 = 2.178254%
    // in BPS = 0.02178254 * 1e4 = 217 BPS
    uint256 feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      400_000 * 1e8,
      0 * 1e8,
      500_000 * 1e8,
      2.56 * 1e8,
      0.5373 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 217);

    // c = sd / p
    // c = 210 / 1.2 = 175
    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 175/100)) = 2
    // y = 0.0007 + ((min(220_000/300_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(220_000/300_000, 1))^2) * 0.05
    // y = 0.0007 + (0.73333333)^2 * 0.05
    // y = 0.0007 + 0.53777777 * 0.05
    // y = 0.02758889 = 2.758889%
    // in BPS = 0.02758889 * 1e4 = 275 BPS
    feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      100_000 * 1e8,
      120_000 * 1e8,
      300_000 * 1e8,
      210 * 1e8,
      1.2 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 275);

    // c = sd / p
    // c = 2.56 / 0.5373 = 4.76456356
    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 4.76456356/100)) = 3.87005578
    // y = 0.0007 + ((min(400_000/500_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(400_000/500_000, 1))^3.87005578) * 0.05
    // y = 0.0007 + (0.8)^3.87005578) * 0.05
    // y = 0.0007 + 0.42165072 * 0.05
    // y = 0.02178254 = 2.178254%
    // in BPS = 0.02178254 * 1e4 = 217 BPS
    feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      400_000 * 1e8,
      0 * 1e8,
      500_000 * 1e8,
      2.56 * 1e8,
      0.5373 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 217);
  }
}
