// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPriceAdapter {
  function getPrice() external view returns (uint256 price);
}
