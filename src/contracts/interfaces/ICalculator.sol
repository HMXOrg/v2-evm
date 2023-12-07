// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

interface ICalculator {
  /**
   * Errors
   */
  error ICalculator_InvalidAddress();
  error ICalculator_InvalidArray();
  error ICalculator_InvalidAveragePrice();
  error ICalculator_InvalidPrice();
  error ICalculator_PoolImbalance();
  error ICalculator_InvalidBorrowingFee();

  /**
   * Structs
   */
  struct GetFundingRateVar {
    uint256 fundingInterval;
    int256 marketSkewUSDE30;
    int256 ratio;
    int256 fundingRateVelocity;
    int256 elapsedIntervals;
  }

  enum LiquidityDirection {
    ADD,
    REMOVE
  }

  enum PositionExposure {
    LONG,
    SHORT
  }

  /**
   * States
   */
  function oracle() external view returns (address _address);

  function vaultStorage() external view returns (address _address);

  function configStorage() external view returns (address _address);

  function perpStorage() external view returns (address _address);

  /**
   * Functions
   */

  function getAUME30(bool isMaxPrice) external view returns (uint256);

  function getGlobalPNLE30() external view returns (int256);

  function getHLPValueE30(bool isMaxPrice) external view returns (uint256);

  function getFreeCollateral(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) external view returns (int256 _freeCollateral);

  function getHLPPrice(uint256 aum, uint256 supply) external view returns (uint256);

  function getMintAmount(uint256 _aum, uint256 _totalSupply, uint256 _amount) external view returns (uint256);

  function getAddLiquidityFeeBPS(
    address _token,
    uint256 _tokenValue,
    ConfigStorage _configStorage
  ) external view returns (uint32);

  function getRemoveLiquidityFeeBPS(
    address _token,
    uint256 _tokenValueE30,
    ConfigStorage _configStorage
  ) external view returns (uint32);

  function getEquity(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) external view returns (int256 _equityValueE30);

  function getEquityWithInjectedPrices(
    address _subAccount,
    bytes32[] memory _injectedAssetIds,
    uint256[] memory _injectedPrices
  ) external view returns (int256 _equityValueE30);

  function getUnrealizedPnlAndFee(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) external view returns (int256 _unrealizedPnlE30, int256 _unrealizedFeeE30);

  function getIMR(address _subAccount) external view returns (uint256 _imrValueE30);

  function getMMR(address _subAccount) external view returns (uint256 _mmrValueE30);

  function getSettlementFeeRate(address _token, uint256 _liquidityUsdDelta) external view returns (uint256);

  function getCollateralValue(
    address _subAccount,
    uint256 _limitPrice,
    bytes32 _assetId
  ) external view returns (uint256 _collateralValueE30);

  function getFundingRateVelocity(uint256 _marketIndex) external view returns (int256);

  function getDelta(IPerpStorage.Position memory position, uint256 _markPrice) external view returns (bool, uint256);

  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice,
    uint256 _lastIncreaseTimestamp,
    uint256 _marketIndex
  ) external view returns (bool, uint256);

  function getPendingBorrowingFeeE30() external view returns (uint256);

  function convertTokenDecimals(
    uint256 _fromTokenDecimals,
    uint256 _toTokenDecimals,
    uint256 _amount
  ) external pure returns (uint256);

  function calculatePositionIMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _imrE30);

  function calculatePositionMMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _mmrE30);

  function setOracle(address _oracle) external;

  function setVaultStorage(address _address) external;

  function setConfigStorage(address _address) external;

  function setPerpStorage(address _address) external;

  function setTradeHelper(address _address) external;

  function proportionalElapsedInDay(uint256 _marketIndex) external view returns (uint256 elapsed);

  function getNextBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _hlpTVL
  ) external view returns (uint256 _nextBorrowingRate);

  function getFundingFee(
    int256 _size,
    int256 _currentFundingAccrued,
    int256 _lastFundingAccrued
  ) external view returns (int256 fundingFee);

  function getBorrowingFee(
    uint8 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate
  ) external view returns (uint256 borrowingFee);
}
