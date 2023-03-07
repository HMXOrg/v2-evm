// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Interfaces
import { IPLPv2 } from "./interfaces/IPLPv2.sol";

contract PLPv2 is ReentrancyGuard, Ownable, ERC20("PLPv2", "Perp88 LP v2") {
  mapping(address => bool) public minters;

  event SetMinter(address indexed minter, bool isMinter);

  /**
   * Modifiers
   */

  modifier onlyMinter() {
    if (!minters[msg.sender]) {
      revert IPLPv2.IPLPv2_onlyMinter();
    }
    _;
  }

  function setMinter(address minter, bool isMinter) external onlyOwner nonReentrant {
    minters[minter] = isMinter;
    emit SetMinter(minter, isMinter);
  }

  function mint(address to, uint256 amount) external onlyMinter nonReentrant {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) external onlyMinter nonReentrant {
    _burn(from, amount);
  }
}
