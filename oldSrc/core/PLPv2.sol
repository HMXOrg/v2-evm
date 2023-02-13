// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PLPv2 is Owned, ERC20("PLPv2", "Perp88 LP v2") {
  mapping(address => bool) public minters;

  event SetMinter(address indexed minter, bool isMinter);

  function setMinter(address minter, bool isMinter) external onlyOwner {
    minters[minter] = isMinter;
    emit SetMinter(minter, isMinter);
  }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) external {
    _burn(from, amount);
  }
}
