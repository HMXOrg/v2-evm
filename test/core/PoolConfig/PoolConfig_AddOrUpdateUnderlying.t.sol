// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolConfig_BaseTest, PoolConfig} from "./PoolConfig_BaseTest.t.sol";

contract PoolConfig_AddOrUpdateUnderlyingTest is PoolConfig_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  /// @notice Test revert when array length is not equal.
  function testRevert_WhenArrayLengthIsNotEqual() external {
    // prepare tokens
    address[] memory tokens = new address[](1);
    tokens[0] = address(weth);

    // prepare configs with different length
    PoolConfig.UnderlyingConfig[] memory configs =
      new PoolConfig.UnderlyingConfig[](2);
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 100
    });
    configs[1] =
      PoolConfig.UnderlyingConfig({isAccept: true, decimals: 18, weight: 100});

    vm.expectRevert(abi.encodeWithSignature("PoolConfig_BadLen()"));
    poolConfig.addOrUpdateUnderlying(tokens, configs);
  }

  /// @notice Test revert when configs contain isAccept = false.
  function testRevert_WhenIsAcceptIsFalse() external {
    // prepare tokens
    address[] memory tokens = new address[](1);
    tokens[0] = address(weth);

    // prepare configs with different length
    PoolConfig.UnderlyingConfig[] memory configs =
      new PoolConfig.UnderlyingConfig[](1);
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: false,
      decimals: weth.decimals(),
      weight: 100
    });

    vm.expectRevert(abi.encodeWithSignature("PoolConfig_BadArgs()"));
    poolConfig.addOrUpdateUnderlying(tokens, configs);
  }

  /// @notice Test revert when owner is not a caller
  function testRevert_WhenNotOwnerCall() external {
    // prepare tokens
    address[] memory tokens = new address[](1);
    tokens[0] = address(weth);

    // prepare configs with different length
    PoolConfig.UnderlyingConfig[] memory configs =
      new PoolConfig.UnderlyingConfig[](1);
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 100
    });

    vm.startPrank(ALICE);
    vm.expectRevert();
    poolConfig.addOrUpdateUnderlying(tokens, configs);
    vm.stopPrank();
  }

  /// @notice test correctness when adding a new underlying
  function testCorrectness_WhenAddNewUnderlying() external {
    // prepare tokens
    address[] memory tokens = new address[](1);
    tokens[0] = address(weth);

    // prepare configs with different length
    PoolConfig.UnderlyingConfig[] memory configs =
      new PoolConfig.UnderlyingConfig[](1);
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 100
    });

    // add new underlying
    poolConfig.addOrUpdateUnderlying(tokens, configs);

    // check correctness
    (bool isAccept, uint8 decimals, uint64 weight) =
      poolConfig.underlyingConfigs(address(weth));

    assertTrue(isAccept);
    assertEq(decimals, weth.decimals());
    assertEq(weight, 100);
    assertEq(poolConfig.totalUnderlyingWeight(), 100);
  }

  /// @notice test correctness when updating an existing underlying
  function testCorrectness_WhenUpdateUnderlying() external {
    // prepare tokens
    address[] memory tokens = new address[](1);
    tokens[0] = address(weth);

    // prepare configs with different length
    PoolConfig.UnderlyingConfig[] memory configs =
      new PoolConfig.UnderlyingConfig[](1);
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 100
    });

    // add new underlying
    poolConfig.addOrUpdateUnderlying(tokens, configs);

    // check correctness
    (bool isAccept, uint8 decimals, uint64 weight) =
      poolConfig.underlyingConfigs(address(weth));

    assertTrue(isAccept);
    assertEq(decimals, weth.decimals());
    assertEq(weight, 100);
    assertEq(poolConfig.totalUnderlyingWeight(), 100);

    // update underlying
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 200
    });
    poolConfig.addOrUpdateUnderlying(tokens, configs);

    // check correctness
    (isAccept, decimals, weight) = poolConfig.underlyingConfigs(address(weth));

    assertTrue(isAccept);
    assertEq(decimals, weth.decimals());
    assertEq(weight, 200);
    assertEq(poolConfig.totalUnderlyingWeight(), 200);
  }

  /// @notice test correctness when updating multiple underlyings at once
  function testCorrectness_WhenUpdateUnderlying2() external {
    // prepare tokens
    address[] memory tokens = new address[](2);
    tokens[0] = address(weth);
    tokens[1] = address(usdc);

    // prepare configs with different length
    PoolConfig.UnderlyingConfig[] memory configs =
      new PoolConfig.UnderlyingConfig[](2);
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 100
    });
    configs[1] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: usdc.decimals(),
      weight: 200
    });

    // add new underlying
    poolConfig.addOrUpdateUnderlying(tokens, configs);

    // check correctness
    (bool isAccept, uint8 decimals, uint64 weight) =
      poolConfig.underlyingConfigs(address(weth));

    assertTrue(isAccept);
    assertEq(decimals, weth.decimals());
    assertEq(weight, 100);
    assertEq(poolConfig.totalUnderlyingWeight(), 300);

    (isAccept, decimals, weight) = poolConfig.underlyingConfigs(address(usdc));

    assertTrue(isAccept);
    assertEq(decimals, usdc.decimals());
    assertEq(weight, 200);
    assertEq(poolConfig.totalUnderlyingWeight(), 300);

    // update underlying
    configs[0] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: weth.decimals(),
      weight: 200
    });
    configs[1] = PoolConfig.UnderlyingConfig({
      isAccept: true,
      decimals: usdc.decimals(),
      weight: 400
    });
    poolConfig.addOrUpdateUnderlying(tokens, configs);

    // check correctness
    (isAccept, decimals, weight) = poolConfig.underlyingConfigs(address(weth));

    assertTrue(isAccept);
    assertEq(decimals, weth.decimals());
    assertEq(weight, 200);

    (isAccept, decimals, weight) = poolConfig.underlyingConfigs(address(usdc));

    assertTrue(isAccept);
    assertEq(decimals, usdc.decimals());
    assertEq(weight, 400);

    assertEq(poolConfig.totalUnderlyingWeight(), 600);
  }
}
