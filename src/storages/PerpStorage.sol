// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
contract PerpStorage is IPerpStorage {
  Global public global; // global state that accumulative value from all markets
  
  Position[] public positions;
  mapping(bytes32 => uint256) public positionIndex;  // bytes32 = primaryAccount + subAccount + marketIndex

  mapping(address => CollateralToken) collateralToken;
  mapping(uint256 => GlobalMarket) public globalMarket;

  constructor(){
  }
}
