// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ICalculator } from "./interfaces/ICalculator.sol";

contract Calculator is ICalculator {
  function getAUM() public view returns (uint256) {
    // TODO assetValue, pendingBorrowingFee
    // plpAUM = value of all asset + pnlShort + pnlLong + pendingBorrowingFee
    uint256 assetValue = 0;
    uint256 pendingBorrowingFee = 0;
    return assetValue + _getPLPPnl(1) + _getPLPPnl(2) + pendingBorrowingFee;
  }

  function getPLPPrice(
    uint256 aum,
    uint256 plpSupply
  ) public view returns (uint256) {
    return aum / plpSupply;
  }

  function _getPLPPnl(uint256 exposure) internal view returns (uint256) {
    //TODO calculate pnl short and long
    return 0;
  }

  function getMintAmount() public view returns (uint256) {
    return 0;
  }

  function convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) public pure returns (uint256) {
    return (amount * 10 ** toTokenDecimals) / 10 ** fromTokenDecimals;
  }
}
