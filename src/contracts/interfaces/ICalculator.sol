// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfigStorage } from "../../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../../storages/interfaces/IVaultStorage.sol";

interface ICalculator {
  //TODO will be use in _getFeeRate
  enum LiquidityDirection {
    ADD,
    REMOVE
  }

  enum PositionExposure {
    LONG,
    SHORT
  }

  error ICalculator_InvalidAddress();
  error ICalculator_InvalidAveragePrice();
  error ICalculator_PoolImbalance();

  function getAUM(bool isMaxPrice) external returns (uint256);

  function getAUME30(bool isMaxPrice) external returns (uint256);

  function getPLPPrice(uint256 aum, uint256 supply) external returns (uint256);

  function getMintAmount(
    uint256 _aum,
    uint256 _totalSupply,
    uint256 _amount
  ) external view returns (uint256);

  function convertTokenDecimals(
    uint256 _fromTokenDecimals,
    uint256 _toTokenDecimals,
    uint256 _amount
  ) external pure returns (uint256);

  function getAddLiquidityFeeRate(
    address _token,
    uint256 _tokenValue,
    IConfigStorage _configStorage,
    IVaultStorage _vaultStorage
  ) external returns (uint256);

  function getRemoveLiquidityFeeRate(
    address _token,
    uint256 _tokenValueE30,
    IConfigStorage _configStorage,
    IVaultStorage _vaultStorage
  ) external returns (uint256);

  function oracle() external returns (address);
}
