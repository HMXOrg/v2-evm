// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import { ICalculator } from "./interfaces/ICalculator.sol";

contract Calculator is Ownable, ICalculator {
  address public oracle;

  event LogSetOracle(address indexed oldOracle, address indexed newOracle);

  constructor(address _oracle) {
    if (_oracle == address(0)) revert InvalidAddress();
    oracle = _oracle;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTERs  ///////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setOracle(address _oracle) external onlyOwner {
    if (_oracle == address(0)) revert InvalidAddress();
    address oldOracle = _oracle;
    oracle = _oracle;
    emit LogSetOracle(oldOracle, oracle);
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATORs
  ////////////////////////////////////////////////////////////////////////////////////

  // Equity = Sum(tokens' Values) + Sum(Pnl) - Unrealized Borrowing Fee - Unrealized Funding Fee
  function getEquity(address _trader) external returns (uint equityValue) {
    // calculate trader's account value from all trader's depositing collateral tokens
    // @todo - implementing
  }
}
