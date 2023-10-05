// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest, console2 } from "@hmx-test/base/BaseTest.sol";
import { ABDKMath64x64 } from "@hmx/libraries/ABDKMath64x64.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { AdaptiveFeeCalculator } from "@hmx/contracts/AdaptiveFeeCalculator.sol";

contract AdaptiveFeeCalculator_Test is BaseTest {
  using ABDKMath64x64 for int128;

  int128 RATE_PRECISION_64x64 = ABDKMath64x64.fromUInt(1e8);
  AdaptiveFeeCalculator adaptiveFeeCalculator;

  function setUp() external {
    adaptiveFeeCalculator = new AdaptiveFeeCalculator();
  }

  function convert64x64ToE8(int128 x) internal view returns (uint256 result) {
    result = ABDKMath64x64.toUInt(ABDKMath64x64.mul(x, RATE_PRECISION_64x64));
  }

  function convertE8To64x64(uint256 input) internal view returns (int128 output) {
    output = ABDKMath64x64.fromUInt(input).div(RATE_PRECISION_64x64);
  }

  function testCorrectness() external {
    // 0.9 / 0.4372 = 1.67535368
    int128 c = convertE8To64x64(1.67535368 * 1e8);

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
    // x = 400_000 + (0 * 1.5)
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
      4.76456356 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 217);

    // c = sd / p
    // c = 210 / 1.2 = 175
    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 175/100)) = 2
    // x = 100_000 + (120_000 * 1.5) = 280000
    // y = 0.0007 + ((min(280000/300000, 1))^g) * 0.05
    // y = 0.0007 + ((min(0.93333333, 1))^2) * 0.05
    // y = 0.0007 + (0.93333333)^2 * 0.05
    // y = 0.0007 + 0.8711111 * 0.05
    // y = 0.04425556 = 4.425556%
    // in BPS = 0.04425556 * 1e4 = 442 BPS
    feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(100_000 * 1e8, 120_000 * 1e8, 300_000 * 1e8, 175 * 1e8, 7, 500);
    assertEq(feeBps, 442);

    // c = sd / p
    // c = 2.56 / 0.5373 = 4.76456356
    // g = 2^(2 - min(1, c/100))
    // g = 2^(2 - min(1, 4.76456356/100)) = 3.87005578
    // x = 400_000 + (400_000 * 1.5) = 1000000
    // y = 0.0007 + ((min(1_000_000/500_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(2, 1))^3.87005578) * 0.05
    // y = 0.0007 + (1)^3.87005578 * 0.05
    // y = 0.0007 + 1 * 0.05
    // y = 0.0507 = 5.07%
    // in BPS = 0.0507 * 1e4 = 507 -> max at 500
    feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      400_000 * 1e8,
      400_000 * 1e8,
      500_000 * 1e8,
      4.76456356 * 1e8,
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
    // x = 400_000_000 + (10_000_000 * 1.5) = 415000000
    // y = 0.0007 + ((min(415_000_000/950_500_000, 1))^g) * 0.05
    // y = 0.0007 + ((min(0.43661231, 1))^4) * 0.05
    // y = 0.0007 + (0.43661231)^4 * 0.05
    // y = 0.0007 + 0.03633991 * 0.05
    // y = 0.002517 = 0.2517%
    // in BPS = 0.002517 * 1e4 = 25 BPS
    uint256 feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      400_000_000 * 1e8,
      10_000_000 * 1e8,
      950_500_000 * 1e8,
      0.00000002 * 1e8,
      7,
      500
    );
    assertEq(feeBps, 25);
  }
}
