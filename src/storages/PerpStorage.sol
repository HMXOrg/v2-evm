// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
contract PerpStorage is IPerpStorage {
  mapping(address => CollateralToken) collateralToken;
  // (marketIndex => GlobalMarket)
  mapping(uint256 => GlobalMarket) public globalMarket;

  Position[] public positions;
  mapping(bytes32 => uint256) public positionIndex;

  Global public global;
}
