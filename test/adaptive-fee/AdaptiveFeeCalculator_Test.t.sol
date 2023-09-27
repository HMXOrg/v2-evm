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

  function convert64x64ToE8(int128 x) internal view returns (uint256 result) {
    result = ABDKMath64x64.toUInt(ABDKMath64x64.mul(x, RATE_PRECISION_64x64));
  }

  function testCorrectness() external {
    uint256 standardDeviationE8 = 0.9 * 1e8;
    uint256 averagePriceE8 = 0.5372 * 1e8;
    // 0.9 / 0.4372 = 1.67535368
    int128 c = adaptiveFeeCalculator.findC(standardDeviationE8, averagePriceE8);
    assertEq(convert64x64ToE8(c), 167535368);

    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 0.01675354))
    // g = 2^(2 - 0.01675354)
    // g = 2^(1.98324646) = 3.95381799
    int128 g = adaptiveFeeCalculator.findG(c);
    assertEq(convert64x64ToE8(g), 395381799);

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
    // y = 0.0007 + ((min(800_000/500_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(1.6, 1))^3.87005578) * 0.05
    // y = 0.0007 + (1)^3.87005578 * 0.05
    // y = 0.0007 + 1 * 0.05
    // y = 0.0507 = 5.07%
    // in BPS = 0.0507 * 1e4 = 507 -> max at 500
    feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      400_000 * 1e8,
      400_000 * 1e8,
      500_000 * 1e8,
      2.56 * 1e8,
      0.5373 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 500);
  }

  function testOverFlow() external {
    // c = sd / p
    // c = 0.0028231 / 138456 = 0.00000002
    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 0.00000002/100)) = 4
    // y = 0.0007 + ((min(410_000_000/950_500_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(0.43135192, 1))^4) * 0.05
    // y = 0.0007 + (0.43135192)^4) * 0.05
    // y = 0.0007 + 0.03461999 * 0.05
    // y = 0.002431 = 0.2431%
    // in BPS = 0.002431 * 1e4 = 24 BPS
    uint256 feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      400_000_000 * 1e8,
      10_000_000 * 1e8,
      950_500_000 * 1e8,
      0.0028231 * 1e8,
      138456 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 24);
  }
}
