// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { console } from "forge-std/console.sol";
import { TickMath } from "@hmx/libraries/TickMath.sol";
import { SqrtX96Codec } from "@hmx/libraries/SqrtX96Codec.sol";
import { PythLib } from "@hmx/libraries/PythLib.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

contract InvestigateTickPrice is ConfigJsonRepo {
  function run() public {
    int64[] memory rawPrices = new int64[](60);
    rawPrices[0] = 147682 * 1e5;
    rawPrices[1] = 147688 * 1e5;
    rawPrices[2] = 147693 * 1e5;
    rawPrices[3] = 147708 * 1e5;
    rawPrices[4] = 147711 * 1e5;
    rawPrices[5] = 147714 * 1e5;
    rawPrices[6] = 147704 * 1e5;
    rawPrices[7] = 147701 * 1e5;
    rawPrices[8] = 147702 * 1e5;
    rawPrices[9] = 147701 * 1e5;
    rawPrices[10] = 147704 * 1e5;
    rawPrices[11] = 147701 * 1e5;
    rawPrices[12] = 147700 * 1e5;
    rawPrices[13] = 147696 * 1e5;
    rawPrices[14] = 147697 * 1e5;
    rawPrices[15] = 147696 * 1e5;
    rawPrices[16] = 147696 * 1e5;
    rawPrices[17] = 147693 * 1e5;
    rawPrices[18] = 147699 * 1e5;
    rawPrices[19] = 147692 * 1e5;
    rawPrices[20] = 147711 * 1e5;
    rawPrices[21] = 147701 * 1e5;
    rawPrices[22] = 147701 * 1e5;
    rawPrices[23] = 147696 * 1e5;
    rawPrices[24] = 147696 * 1e5;
    rawPrices[25] = 147696 * 1e5;
    rawPrices[26] = 147693 * 1e5;
    rawPrices[27] = 147692 * 1e5;
    rawPrices[28] = 147684 * 1e5;
    rawPrices[29] = 147686 * 1e5;
    rawPrices[30] = 147685 * 1e5;
    rawPrices[31] = 147685 * 1e5;
    rawPrices[32] = 147671 * 1e5;
    rawPrices[33] = 147674 * 1e5;
    rawPrices[34] = 147673 * 1e5;
    rawPrices[35] = 147675 * 1e5;
    rawPrices[36] = 147686 * 1e5;
    rawPrices[37] = 147680 * 1e5;
    rawPrices[38] = 147680 * 1e5;
    rawPrices[39] = 147672 * 1e5;
    rawPrices[40] = 147640 * 1e5;
    rawPrices[41] = 147652 * 1e5;
    rawPrices[42] = 147657 * 1e5;
    rawPrices[43] = 147649 * 1e5;
    rawPrices[44] = 147642 * 1e5;
    rawPrices[45] = 147642 * 1e5;
    rawPrices[46] = 147641 * 1e5;
    rawPrices[47] = 147640 * 1e5;
    rawPrices[48] = 147643 * 1e5;
    rawPrices[49] = 147623 * 1e5;
    rawPrices[50] = 147610 * 1e5;
    rawPrices[51] = 147589 * 1e5;
    rawPrices[52] = 147603 * 1e5;
    rawPrices[53] = 147608 * 1e5;
    rawPrices[54] = 147597 * 1e5;
    rawPrices[55] = 147607 * 1e5;
    rawPrices[56] = 147616 * 1e5;
    rawPrices[57] = 147629 * 1e5;
    rawPrices[58] = 147648 * 1e5;
    rawPrices[59] = 147636 * 1e5;
    for (uint256 i = 0; i < rawPrices.length; i++) {
      int24 tick = TickMath.getTickAtSqrtRatio(SqrtX96Codec.encode(PythLib.convertToUint(rawPrices[i], -8, 18)));
      uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
      uint256 spotPrice = (uint256(sqrtPriceX96) * (uint256(sqrtPriceX96)) * (1e8)) >> (96 * 2);

      PythStructs.Price memory priceStruct;
      priceStruct.price = int64(int256(spotPrice));
      priceStruct.expo = -8;

      uint256 flippedPrice = _convertToUint256(priceStruct, false, 30, true);
      console.log(i, flippedPrice);
    }
  }

  function _convertToUint256(
    PythStructs.Price memory _priceStruct,
    bool /*_isMax*/,
    uint8 _targetDecimals,
    bool _shouldInvert
  ) private pure returns (uint256) {
    uint8 _priceDecimals = uint8(uint32(-1 * _priceStruct.expo));

    uint64 _price = uint64(_priceStruct.price);

    uint256 _price256;
    if (_targetDecimals - _priceDecimals >= 0) {
      _price256 = uint256(_price) * 10 ** uint32(_targetDecimals - _priceDecimals);
    } else {
      _price256 = uint256(_price) / 10 ** uint32(_priceDecimals - _targetDecimals);
    }

    if (!_shouldInvert) {
      return _price256;
    }

    // Quote inversion. This is an intention to support the price like USD/JPY.
    {
      // Safe div 0 check, possible when _priceStruct.price == _priceStruct.conf
      if (_price256 == 0) return 0;

      // Formula: inverted price = 10^2N / priceEN, when N = target decimal
      //
      // Example: Given _targetDecimals = 30, inverted quote price can be calculated as followed.
      // inverted price = 10^60 / priceE30
      return 10 ** uint32(_targetDecimals * 2) / _price256;
    }
  }
}
