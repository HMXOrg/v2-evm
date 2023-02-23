// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfigStorage } from "../../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../../storages/interfaces/IVaultStorage.sol";

interface ICalculator {
  /**
   * ERRORS
   */
  error ICalculator_InvalidAddress();
  error ICalculator_InvalidAveragePrice();
  error ICalculator_PoolImbalance();

  /**
   * STRUCTS
   */
  struct GetFundingRateVar {
    uint256 fundingInterval;
    uint256 marketPriceE30;
    int256 marketSkewUSDE30;
    int256 tempMaxValue;
    int256 tempMinValue;
    int256 nextFundingRate;
    int256 newFundingRate;
    int256 elaspedIntervals;
  }

  //@todo - will be use in _getFeeRate
  enum LiquidityDirection {
    ADD,
    REMOVE
  }

  enum PositionExposure {
    LONG,
    SHORT
  }

  function getAUM(bool isMaxPrice) external returns (uint256);

  function getAUME30(bool isMaxPrice) external returns (uint256);

  function getPLPValueE30(bool isMaxPrice) external view returns (uint256);

  function getFreeCollateral(address _subAccount) external returns (uint256);

  function getPLPPrice(uint256 aum, uint256 supply) external returns (uint256);

  function getMintAmount(uint256 _aum, uint256 _totalSupply, uint256 _amount) external view returns (uint256);

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

  function calculatePositionIMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _imrE30);

  function calculatePositionMMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _mmrE30);

  function getEquity(address _subAccount) external returns (uint256 _equityValueE30);

  function getUnrealizedPnl(address _subAccount) external view returns (int _unrealizedPnlE30);

  function getIMR(address _subAccount) external view returns (uint256 _imrValueE30);

  function getMMR(address _subAccount) external view returns (uint256 _mmrValueE30);

  function getNextFundingRate(
    uint256 marketIndex
  ) external view returns (int256 fundingRate, int256 fundingRateLong, int256 fundingRateShort);
}
