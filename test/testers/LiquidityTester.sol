// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Forge
import { StdAssertions } from "forge-std/StdAssertions.sol";
// HMX
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
// OZ
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquidityTester is StdAssertions {
  /**
   * Structs
   */
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

  /**
   * States
   */
  ERC20 plp;

  OracleMiddleware oracleMiddleware;

  ConfigStorage configStorage;
  PerpStorage perpStorage;
  VaultStorage vaultStorage;

  address feeReceiver;

  constructor(
    address _plp,
    address _configStorage,
    address _perpStorage,
    address _vaultStorage,
    address _oracleMiddleware,
    address _feeReceiver
  ) {
    plp = ERC20(_plp);
    configStorage = ConfigStorage(_configStorage);
    perpStorage = PerpStorage(_perpStorage);
    vaultStorage = VaultStorage(_vaultStorage);
    oracleMiddleware = OracleMiddleware(_oracleMiddleware);
    feeReceiver = _feeReceiver;
  }

  function _convertDecimals(
    uint256 _amount,
    uint256 _fromDecimals,
    uint256 _toDecimals
  ) internal pure returns (uint256) {
    if (_fromDecimals == _toDecimals) {
      return _amount;
    } else if (_fromDecimals > _toDecimals) {
      return _amount / (10 ** (_fromDecimals - _toDecimals));
    } else {
      return _amount * (10 ** (_toDecimals - _fromDecimals));
    }
  }

  function expectLiquidityMint(
    bytes32 _assetId,
    uint256 _amountIn
  ) external view returns (uint256 _liquidity, uint256 _fee) {
    // Load liquidity config
    ConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
    // Load asset config
    ConfigStorage.AssetConfig memory _assetConfig = configStorage.getAssetConfig(_assetId);
    // Load calculator
    Calculator _calculator = Calculator(configStorage.calculator());
    // Apply deposit fee bps
    uint256 _amountInAfterFee = 0;
    if (!_liquidityConfig.dynamicFeeEnabled) {
      _fee = (_amountIn * _liquidityConfig.depositFeeRateBPS) / 10000;
      _amountInAfterFee = _amountIn - _fee;
    } else {
      // TODO: implement dynamic fee
      revert("Not implemented");
    }
    // Look up asset price from oracle
    (uint256 _assetMinPrice, ) = oracleMiddleware.getLatestPrice(_assetId, false);
    // Calculate liquidity
    uint256 _amountInUSDe30 = _convertDecimals((_amountInAfterFee * _assetMinPrice) / 1e30, _assetConfig.decimals, 30);
    _liquidity = plp.totalSupply() == 0
      ? _amountInUSDe30 / 1e12
      : (_amountInUSDe30 * plp.totalSupply()) / _calculator.getAUME30(false, 0, 0);
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
    assertEq(vaultStorage.protocolFees(_token), _expectedData.fee, "Protocol Fee");
    assertEq(vaultStorage.totalAmount(_token), vaultStorage.plpLiquidity(_token) + vaultStorage.protocolFees(_token));

    // Check token balance
    // balanceOf must be equals to plpLiquidity in Vault
    assertEq(ERC20(_token).balanceOf(address(vaultStorage)), _expectedData.totalAmount, "Vault Storage Token Balance");
  }
}
