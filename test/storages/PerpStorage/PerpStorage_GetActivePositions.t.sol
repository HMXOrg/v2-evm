// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

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
}
