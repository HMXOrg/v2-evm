// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

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
    int256 ratio;
    int256 nextFundingRate;
    int256 elapsedIntervals;
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

  function getFreeCollateral(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) external view returns (uint256 _freeCollateral);

  function getPLPPrice(uint256 aum, uint256 supply) external returns (uint256);

  function getMintAmount(uint256 _aum, uint256 _totalSupply, uint256 _amount) external view returns (uint256);

  function convertTokenDecimals(
    uint256 _fromTokenDecimals,
    uint256 _toTokenDecimals,
    uint256 _amount
  ) external pure returns (uint256);

  function getAddLiquidityFeeBPS(
    address _token,
    uint256 _tokenValue,
    ConfigStorage _configStorage
  ) external returns (uint32);

  function getRemoveLiquidityFeeBPS(
    address _token,
    uint256 _tokenValueE30,
    ConfigStorage _configStorage
  ) external returns (uint32);

  function calculatePositionIMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _imrE30);

  function calculatePositionMMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _mmrE30);

  function getEquity(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) external view returns (int256 _equityValueE30);

  function getUnrealizedPnlAndFee(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) external view returns (int256 _unrealizedPnlE30, int256 _unrealizedFeeE30);

  function getIMR(address _subAccount) external view returns (uint256 _imrValueE30);

  function getMMR(address _subAccount) external view returns (uint256 _mmrValueE30);

  function getSettlementFeeRate(address _token, uint256 _liquidityUsdDelta) external returns (uint256);

  function getCollateralValue(
    address _subAccount,
    uint256 _limitPrice,
    bytes32 _assetId
  ) external view returns (uint256 _collateralValueE30);

  function getNextFundingRate(uint256 _marketIndex) external view returns (int256, int256, int256);

  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice,
    uint256 _lastincreaseTimestamp
  ) external view returns (bool, uint256);

  function setOracle(address _oracle) external;

  function setVaultStorage(address _address) external;

  function setConfigStorage(address _address) external;

  function setPerpStorage(address _address) external;

  function oracle() external returns (address _address);

  function vaultStorage() external returns (address _address);

  function configStorage() external returns (address _address);

  function perpStorage() external returns (address _address);

  function getPendingBorrowingFeeE30() external view returns (uint256);
}
