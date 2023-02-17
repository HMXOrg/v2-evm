// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

import { Owned } from "../base/Owned.sol";

// Interfaces
import { ICalculator } from "./interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";

contract Calculator is Owned, ICalculator {
  // using libs for type
  using AddressUtils for address;

  // EVENTS
  event LogSetOracle(address indexed oldOracle, address indexed newOracle);
  event LogSetVaultStorage(
    address indexed oldVaultStorage,
    address indexed vaultStorage
  );
  event LogSetConfigStorage(
    address indexed oldConfigStorage,
    address indexed configStorage
  );
  event LogSetPerpStorage(
    address indexed oldPerpStorage,
    address indexed perpStorage
  );

  // STATES
  // @todo - move oracle config to storage
  address public oracle;
  address public vaultStorage;
  address public configStorage;
  address public perpStorage;

  constructor(
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) {
    // @todo - Sanity check
    if (
      _oracle == address(0) ||
      _vaultStorage == address(0) ||
      _perpStorage == address(0) ||
      _configStorage == address(0)
    ) revert ICalculator_InvalidAddress();
    oracle = _oracle;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    perpStorage = _perpStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTERs  ///////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  /// @notice Set new Oracle contract address.
  /// @param _oracle New Oracle contract address.
  function setOracle(address _oracle) external onlyOwner {
    // @todo - Sanity check
    if (_oracle == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetOracle(oracle, _oracle);
    oracle = _oracle;
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external onlyOwner {
    // @todo - Sanity check
    if (_vaultStorage == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;
  }

  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external onlyOwner {
    // @todo - Sanity check
    if (_configStorage == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external onlyOwner {
    // @todo - Sanity check
    if (_perpStorage == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATOR
  ////////////////////////////////////////////////////////////////////////////////////

  /// @notice Calculate for value on trader's account including Equity, IMR and MMR.
  /// @dev Equity = Sum(collateral tokens' Values) + Sum(unrealized PnL) - Unrealized Borrowing Fee - Unrealized Funding Fee
  /// @param _subAccount Trader account's address.
  /// @return _equityValueE30 Total equity of trader's account.
  function getEquity(
    address _subAccount
  ) external returns (uint256 _equityValueE30) {
    // Calculate collateral tokens' value on trader's sub account
    uint256 _collateralValueE30 = getCollateralValue(_subAccount);

    // Calculate unrealized PnL on opening trader's position(s)
    int256 _unrealizedPnlValueE30 = getUnrealizedPnl(_subAccount);

    // Calculate Borrwing fee on opening trader's position(s)
    // @todo - calculate borrowing fee
    // uint256 borrowingFeeE30 = getBorrowingFee(_subAccount);

    // @todo - calculate funding fee
    // uint256 fundingFeeE30 = getFundingFee(_subAccount);

    // Sum all asset's values
    _equityValueE30 += _collateralValueE30;

    if (_unrealizedPnlValueE30 > 0) {
      _equityValueE30 += uint256(_unrealizedPnlValueE30);
    } else {
      _equityValueE30 -= uint256(-_unrealizedPnlValueE30);
    }

    // @todo - include borrowing and funding fee
    // _equityValueE30 -= borrowingFeeE30;
    // _equityValueE30 -= fundingFeeE30;

    return _equityValueE30;
  }

  /// @notice Calculate unrealized PnL from trader's sub account.
  /// @dev This unrealized pnl deducted by collateral factor.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _unrealizedPnlE30 PnL value after deducted by collateral factor.
  function getUnrealizedPnl(
    address _subAccount
  ) public view returns (int256 _unrealizedPnlE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage)
      .getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      IPerpStorage.Position memory _position = _traderPositions[i];
      bool _isLong = _position.positionSizeE30 > 0 ? true : false;

      if (_position.avgEntryPriceE30 == 0)
        revert ICalculator_InvalidAveragePrice();

      // Get market config according to opening position
      IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
        configStorage
      ).getMarketConfigByIndex(_position.marketIndex);

      // Long position always use MinPrice. Short position always use MaxPrice
      bool _isUseMaxPrice = _isLong ? false : true;

      // Get price from oracle
      // @todo - validate price age
      (uint256 _priceE30, , ) = IOracleMiddleware(oracle)
        .getLatestPriceWithMarketStatus(
          _marketConfig.assetId,
          _isUseMaxPrice,
          _marketConfig.priceConfidentThreshold,
          0
        );

      // Calculate for priceDelta
      uint256 _priceDeltaE30;
      unchecked {
        _priceDeltaE30 = _position.avgEntryPriceE30 > _priceE30
          ? _position.avgEntryPriceE30 - _priceE30
          : _priceE30 - _position.avgEntryPriceE30;
      }

      int256 _delta = (_position.positionSizeE30 * int(_priceDeltaE30)) /
        int(_position.avgEntryPriceE30);

      if (_isLong) {
        _delta = _priceE30 > _position.avgEntryPriceE30 ? _delta : -_delta;
      } else {
        _delta = _priceE30 < _position.avgEntryPriceE30 ? -_delta : _delta;
      }

      // If profit then deduct PnL with colleral factor.
      _delta = _delta > 0
        ? (int(IConfigStorage(configStorage).pnlFactor()) * _delta) / 1e18
        : _delta;

      // Accumulative current unrealized PnL
      _unrealizedPnlE30 += _delta;

      unchecked {
        i++;
      }
    }

    return _unrealizedPnlE30;
  }

  /// @notice Calculate collateral tokens to value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _collateralValueE30
  function getCollateralValue(
    address _subAccount
  ) public returns (uint256 _collateralValueE30) {
    // Get list of current depositing tokens on trader's account
    address[] memory _traderTokens = IVaultStorage(vaultStorage)
      .getTraderTokens(_subAccount);

    // Loop through list of current depositing tokens
    for (uint256 i; i < _traderTokens.length; ) {
      address _token = _traderTokens[i];

      // Get token decimals from ConfigStorage
      uint256 _decimals = ERC20(_token).decimals();

      // Get collateralFactor from ConfigStorage
      uint256 _collateralFactor = IConfigStorage(configStorage)
        .getCollateralTokenConfigs(_token)
        .collateralFactor;

      // Get priceConfidentThreshold from ConfigStorage
      uint256 _priceConfidenceThreshold = IConfigStorage(configStorage)
        .getMarketConfigByToken(_token)
        .priceConfidentThreshold;

      // Get current collateral token balance of trader's account
      uint256 _amount = IVaultStorage(vaultStorage).traderBalances(
        _subAccount,
        _token
      );

      bool _isMaxPrice = false; // @note Collateral value always use Min price
      // Get price from oracle
      // @todo - validate price age
      (uint256 _priceE30, , ) = IOracleMiddleware(oracle)
        .getLatestPriceWithMarketStatus(
          _token.toBytes32(),
          _isMaxPrice,
          _priceConfidenceThreshold,
          0
        );

      // Calculate accumulative value of collateral tokens
      // collateal value = (collateral amount * price) * collateralFactor
      // collateralFactor 1 ether = 100%
      _collateralValueE30 +=
        (_amount * _priceE30 * _collateralFactor) /
        (10 ** _decimals * 1e18);

      unchecked {
        i++;
      }
    }

    return _collateralValueE30;
  }

  /// @notice Calculate Intial Margin Requirement from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _imrValueE30 Total imr of trader's account.
  function getIMR(
    address _subAccount
  ) public view returns (uint256 _imrValueE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage)
      .getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      IPerpStorage.Position memory _position = _traderPositions[i];

      uint256 _size;
      if (_position.positionSizeE30 < 0) {
        _size = uint(_position.positionSizeE30 * -1);
      } else {
        _size = uint(_position.positionSizeE30);
      }

      // Calculate IMR on position
      _imrValueE30 += calculatePositionIMR(_size, _position.marketIndex);

      unchecked {
        i++;
      }
    }

    return _imrValueE30;
  }

  /// @notice Calculate Maintenance Margin Value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _mmrValueE30 Total mmr of trader's account
  function getMMR(
    address _subAccount
  ) public view returns (uint256 _mmrValueE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage)
      .getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      IPerpStorage.Position memory _position = _traderPositions[i];

      uint256 _size;
      if (_position.positionSizeE30 < 0) {
        _size = uint(_position.positionSizeE30 * -1);
      } else {
        _size = uint(_position.positionSizeE30);
      }
      // Calculate MMR on position
      _mmrValueE30 += calculatePositionMMR(_size, _position.marketIndex);

      unchecked {
        i++;
      }
    }

    return _mmrValueE30;
  }

  /// @notice Calculate for Initial Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _imrE30 The IMR amount required on position size, 30 decimals.
  function calculatePositionIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) public view returns (uint256 _imrE30) {
    // Get market config according to position
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    _imrE30 = (_positionSizeE30 * _marketConfig.initialMarginFraction) / 1e18;
    return _imrE30;
  }

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _mmrE30 The MMR amount required on position size, 30 decimals.
  function calculatePositionMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) public view returns (uint256 _mmrE30) {
    // Get market config according to position
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    _mmrE30 =
      (_positionSizeE30 * _marketConfig.maintenanceMarginFraction) /
      1e18;
    return _mmrE30;
  }
}
