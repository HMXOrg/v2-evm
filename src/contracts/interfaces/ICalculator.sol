// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfigStorage } from "../../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../../storages/interfaces/IVaultStorage.sol";

interface ICalculator {
  enum LiquidityDirection {
    ADD,
    REMOVE
  }

  enum PositionExposure {
    LONG,
    SHORT
  }

  function getAUM() external returns (uint256);

  function getPLPPrice(uint256 aum, uint256 supply) external returns (uint256);

  function getMintAmount(
    uint256 _aum,
    uint256 _totalSupply,
    uint256 _amount
  ) external view returns (uint256);

  function convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) external pure returns (uint256);

  function getAddLiquidityFeeRate(
    address _token,
    uint256 _tokenValue,
    IConfigStorage _liquidityConfig,
    IVaultStorage _vaultStorage
  ) external returns (uint256);
}
