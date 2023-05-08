// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { PerpStorage_Base } from "./PerpStorage_Base.t.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract PerpStorage_GetActivePositions is PerpStorage_Base {
  function setUp() public override {
    super.setUp();

    for (uint256 i; i < 5; i++) {
      _savePosition(ALICE, bytes32(uint256(100 + i)));
    }
    for (uint256 i; i < 13; i++) {
      _savePosition(BOB, bytes32(uint256(200 + i)));
    }
    for (uint256 i; i < 7; i++) {
      _savePosition(CAROL, bytes32(uint256(300 + i)));
    }
    for (uint256 i; i < 3; i++) {
      _savePosition(DAVE, bytes32(uint256(400 + i)));
    }

    // total 28 positions
  }

  function testCorrectness_WhenGetActivePositions() external {
    IPerpStorage.Position[] memory _positions;
    {
      _positions = pStorage.getActivePositions(5, 0);
      assertEq(_positions.length, 5);
      _positions = pStorage.getActivePositions(5, 5);
      assertEq(_positions.length, 5);
      _positions = pStorage.getActivePositions(5, 10);
      assertEq(_positions.length, 5);
      _positions = pStorage.getActivePositions(5, 15);
      assertEq(_positions.length, 5);
      _positions = pStorage.getActivePositions(5, 20);
      assertEq(_positions.length, 5);
      _positions = pStorage.getActivePositions(5, 25);
      assertEq(_positions.length, 3);
      _positions = pStorage.getActivePositions(5, 30);
      assertEq(_positions.length, 0);
    }

    {
      _positions = pStorage.getActivePositions(1000, 0);
      assertEq(_positions.length, 28);

      _removePosition(ALICE, bytes32(uint256(100)));
      _removePosition(ALICE, bytes32(uint256(101)));

      _positions = pStorage.getActivePositions(1000, 0);
      assertEq(_positions.length, 26);
    }
  }

  function testCorrectness_WhenGetActivePositionIds() external {
    bytes32[] memory _positionIds;
    {
      _positionIds = pStorage.getActivePositionIds(5, 0);
      assertEq(_positionIds.length, 5);
      _positionIds = pStorage.getActivePositionIds(5, 5);
      assertEq(_positionIds.length, 5);
      _positionIds = pStorage.getActivePositionIds(5, 10);
      assertEq(_positionIds.length, 5);
      _positionIds = pStorage.getActivePositionIds(5, 15);
      assertEq(_positionIds.length, 5);
      _positionIds = pStorage.getActivePositionIds(5, 20);
      assertEq(_positionIds.length, 5);
      _positionIds = pStorage.getActivePositionIds(5, 25);
      assertEq(_positionIds.length, 3);
      _positionIds = pStorage.getActivePositionIds(5, 30);
      assertEq(_positionIds.length, 0);
    }

    {
      _positionIds = pStorage.getActivePositionIds(1000, 0);
      assertEq(_positionIds.length, 28);

      _removePosition(ALICE, bytes32(uint256(100)));
      _removePosition(ALICE, bytes32(uint256(101)));

      _positionIds = pStorage.getActivePositionIds(1000, 0);
      assertEq(_positionIds.length, 26);
    }
  }

  function testCorrectness_WhenGetActiveSubAccounts() external {
    address[] memory _subAccounts;
    {
      _subAccounts = pStorage.getActiveSubAccounts(2, 0);
      assertEq(_subAccounts.length, 2);
      _subAccounts = pStorage.getActiveSubAccounts(2, 2);
      assertEq(_subAccounts.length, 2);
      _subAccounts = pStorage.getActiveSubAccounts(2, 4);
      assertEq(_subAccounts.length, 0);
    }

    {
      _subAccounts = pStorage.getActiveSubAccounts(1000, 0);
      assertEq(_subAccounts.length, 4);

      _removePosition(ALICE, bytes32(uint256(100)));
      _removePosition(ALICE, bytes32(uint256(101)));

      _subAccounts = pStorage.getActiveSubAccounts(1000, 0);
      assertEq(_subAccounts.length, 4);

      _removePosition(ALICE, bytes32(uint256(102)));
      _removePosition(ALICE, bytes32(uint256(103)));
      _removePosition(ALICE, bytes32(uint256(104)));

      _subAccounts = pStorage.getActiveSubAccounts(1000, 0);
      assertEq(_subAccounts.length, 3);
    }
  }

  function testX() external {
    AStorage aStorage = new AStorage();

    assertEq(aStorage.getStorageAt(0), 1);
    assertEq(aStorage.getStorageAt(1), 2);
    assertEq(aStorage.getStorageAt(2), 4);
    assertEq(aStorage.getStorageAt(3), 8);
    assertEq(aStorage.getStorageAt(4), 257);
    assertEq(aStorage.getStorageAt(5), 0);
    assertEq(aStorage.answer(), 261);

    BStorage bStorage = new BStorage();
    assertEq(bStorage.answer(), 4);
    // assertEq(bStorage.getStorageAt(1), 4);
    // assertEq(bStorage.getStorageAt(2), 8);
    // assertEq(bStorage.getStorageAt(3), 0);

    CStorage cStorage = new CStorage();

    assertEq(cStorage.getStorageAt(0), 10);
    assertEq(cStorage.getStorageAt(1), 18);
    assertEq(cStorage.getStorageAt(2), 1);
    assertEq(cStorage.getStorageAt(3), 20);
    assertEq(cStorage.getStorageAt(4), 28);
    assertEq(cStorage.getStorageAt(5), 0);
    assertEq(cStorage.answer(), 39);
    // assertEq(bStorage.getStorageAt(1), 4);
  }
}

contract AStorage {
  uint storage1 = 1;
  uint storage2 = 2;
  uint storage3 = 4;
  uint storage4 = 8;
  bool storage5 = true;
  bool storage6 = true;

  function getStorageAt(uint index) public view returns (uint256 r) {
    assembly {
      r := sload(index)
    }
  }

  function answer() public view returns (uint256) {
    return getStorageAt(2) + getStorageAt(4) + getStorageAt(5);
  }
}

contract BStorage {
  uint8 storage1 = 1;
  uint64 storage2 = 2;
  uint256 storage3 = 4;
  uint128 storage4 = 2;
  uint128 storage5 = 1;

  function getStorageAt(uint index) public view returns (uint8 r) {
    assembly {
      r := sload(index)
    }
  }

  function answer() public view returns (uint256) {
    return getStorageAt(1) + getStorageAt(3);
  }
}

contract CStorage {
  struct Account {
    uint128 balance;
    uint256 age;
    bool isActive;
    address accountAddr;
  }

  Account public acc1 = Account(10, 18, true, address(1));
  Account public acc2 = Account(20, 28, false, address(2));

  function getStorageAt(uint index) public view returns (uint8 r) {
    assembly {
      r := sload(index)
    }
  }

  function answer() public view returns (uint8) {
    return getStorageAt(0) + getStorageAt(2) + getStorageAt(4) + getStorageAt(5);
  }
}
