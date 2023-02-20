// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfigStorage } from "../../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../../storages/interfaces/IVaultStorage.sol";

interface ICalculator {
  // ERRORs
  error ICalculator_InvalidAddress();
  error ICalculator_InvalidAveragePrice();
  error ICalculator_PoolImbalance();

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

  /// @notice Calculate for Initial Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _imrE30 The IMR amount required on position size, 30 decimals.
  function calculatePositionIMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _imrE30);

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _mmrE30 The MMR amount required on position size, 30 decimals.
  function calculatePositionMMR(uint256 _positionSizeE30, uint256 _marketIndex) external view returns (uint256 _mmrE30);

  /// @notice Calculate for value on trader's account including Equity, IMR and MMR.
  /// @dev Equity = Sum(collateral tokens' Values) + Sum(unrealized PnL) - Unrealized Borrowing Fee - Unrealized Funding Fee
  /// @param _subAccount Trader account's address.
  /// @return _equityValueE30 Total equity of trader's account.
  function getEquity(address _subAccount) external returns (uint256 _equityValueE30);

  // @todo - Add Description
  function getUnrealizedPnl(address _subAccount) external view returns (int _unrealizedPnlE30);

  // @todo - Add Description
  /// @return _imrValueE30 Total imr of trader's account.
  function getIMR(address _subAccount) external view returns (uint256 _imrValueE30);

  // @todo - Add Description
  /// @return _mmrValueE30 Total mmr of trader's account
  function getMMR(address _subAccount) external view returns (uint256 _mmrValueE30);
}
