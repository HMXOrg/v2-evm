// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";

/// @title Liquidity Tester
/// @notice This Tester help to check state after user interact with LiquidityHandler / LiquidityService
contract LiquidityTester is StdAssertions {
  /**
   * States
   */
  IPLPv2 plp;

  IVaultStorage vaultStorage;
  IPerpStorage perpStorage;

  address feeReceiver;

  constructor(IPLPv2 _plp, IVaultStorage _vaultStorage, IPerpStorage _perpStorage, address _feeReceiver) {
    plp = _plp;
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
    feeReceiver = _feeReceiver;
  }

  struct LiquidityExpectedData {
    address token;
    address who;
    uint256 lpTotalSupply;
    uint256 totalAmount; // totalAmount in vaultStorage
    uint256 plpLiquidity;
    uint256 plpAmount;
    uint256 fee;
    uint256 executionFee;
  }

  /// @notice Assert function when PLP provider add / remove liquidity
  /// @dev This function will check
  ///      - PLPv2 total supply
  ///      - Execution fee in handler, if address is valid
  ///      - PLP liquidity in VaultStorage's state
  ///      - Total token amount in VaultStorage's state
  ///      - Fee is VaultStorage's state
  ///      - Token balance in VaultStorage
  function assertLiquidityInfo(LiquidityExpectedData memory _expectedData) external {
    address _token = _expectedData.token;

    // Check PLPv2 total supply
    assertEq(plp.totalSupply(), _expectedData.lpTotalSupply, "PLP Total supply");
    assertEq(plp.balanceOf(_expectedData.who), _expectedData.plpAmount, "PLP Amount");

    // Order execution fee is on OrderExecutor in Native
    assertEq(feeReceiver.balance, _expectedData.executionFee, "Execution Order Fee");

    // Check VaultStorage's state
    assertEq(vaultStorage.plpLiquidity(_token), _expectedData.plpLiquidity, "PLP token liquidity amount");
    assertEq(vaultStorage.totalAmount(_token), _expectedData.totalAmount, "TokenAmount balance");
    assertEq(vaultStorage.fees(_token), _expectedData.fee, "Fee");
    assertEq(vaultStorage.totalAmount(_token), vaultStorage.plpLiquidity(_token) + vaultStorage.fees(_token));

    // Check token balance
    // balanceOf must be equals to plpLiquidity in Vault
    assertEq(IERC20(_token).balanceOf(address(vaultStorage)), _expectedData.totalAmount, "Vault Storage Token Balance");
  }
}
