// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// HMX
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
// OZ
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquidityTester {
  ERC20 plp;
  OracleMiddleware oracleMiddleware;
  ConfigStorage configStorage;

  constructor(ERC20 _plp, OracleMiddleware _oracleMiddleware, ConfigStorage _configStorage) {
    plp = _plp;
    oracleMiddleware = _oracleMiddleware;
    configStorage = _configStorage;
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
}
