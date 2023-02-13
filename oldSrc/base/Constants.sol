// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract Constants {
  bytes32 internal constant ADD_LIQUIDITY_ACTION_ID =
    0x1d29eb1064694697b9deb1f072d67c2a04f8dc16c4acb64f306a7072ef260a56;
  bytes32 internal constant REMOVE_LIQUIDITY_ACTION_ID =
    0xfbbe693edc213719e49671b17961d4d006890ac38857804aaf84e87309e89e9c;
  bytes32 internal constant SWAP_ACTION_ID =
    0x564357c5abf9e4427ba99e8ffca0584977f904adf137fa34c70a3f712aea2fae;
  bytes32 internal constant INCREASE_POSITION_ACTION_ID =
    0x39993965f8368a9c9f51221b663e9a842fb32b2282d9de0dafb700464f9b6d0a;
  bytes32 internal constant DECREASE_POSITION_ACTION_ID =
    0x164236de50980b701f79ea243c8a7f29cd20ca71da4eea91a6297f8d28d17fb7;
  bytes32 internal constant LIQUIDATE_POSITION_ACTION_ID =
    0x643df9b5c5f2e08414266e3bf88653940e111c4a4039bb4a82f16f8f9add09dc;

  uint256 internal constant ORACLE_PRICE_PRECISION = 1e30;
  uint8 internal constant ORACLE_PRICE_DECIMALS = 30;

  address internal constant ITERABLE_ADDRESS_LIST_START = address(1);
  address internal constant ITERABLE_ADDRESS_LIST_END = address(1);
  address internal constant ITERABLE_ADDRESS_LIST_EMPTY = address(0);
}
