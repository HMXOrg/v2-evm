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

import { Math } from "../utils/Math.sol";

import { console } from "forge-std/console.sol"; //@todo - remove

contract Calculator is Owned, ICalculator {
  // using libs for type
  using AddressUtils for address;

  // STATES
  address public oracle;
  address public vaultStorage;
  address public configStorage;
  address public perpStorage;

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
  /// @return equityValueE30 Total equity of trader's account.
  function getEquity(
    address _subAccount
  ) external returns (uint256 equityValueE30) {
    // Calculate collateral tokens' value on trader's account
    uint256 collateralValueE30 = getCollateralValue(_subAccount);

    // Calculate unrealized PnL on opening trader's position
    int256 unrealizedPnlValueE30 = getUnrealizedPnl(_subAccount);

    // Calculate Borrwing fee on opening trader's position
    // @todo - calculate borrowing fee
    // uint256 borrowingFeeE30 = getBorrowingFee(_subAccount);

    // @todo - calculate funding fee
    // uint256 fundingFeeE30 = getFundingFee(_subAccount);

    // Sum all asset's values
    equityValueE30 += collateralValueE30;

    if (unrealizedPnlValueE30 > 0) {
      equityValueE30 += Math.abs(unrealizedPnlValueE30);
    } else {
      equityValueE30 -= Math.abs(unrealizedPnlValueE30);
    }

    // @todo - include borrowing and funding fee
    // equityValueE30 -= borrowingFeeE30;
    // equityValueE30 -= fundingFeeE30;

    return equityValueE30;
  }

  /// @notice Calculate unrealized PnL from trader's sub account.
  /// @dev This unrealized pnl deducted by collateral factor.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return unrealizedPnlE30 PnL value after deducted by collateral factor.
  function getUnrealizedPnl(
    address _subAccount
  ) public view returns (int256 unrealizedPnlE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory traderPositions = IPerpStorage(perpStorage)
      .getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < traderPositions.length; ) {
      IPerpStorage.Position memory position = traderPositions[i];
      bool isLong = position.positionSizeE30 > 0 ? true : false;

      if (position.avgEntryPriceE30 == 0)
        revert ICalculator_InvalidAveragePrice();

      // Get market config according to opening position
      IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
        configStorage
      ).getMarketConfigByIndex(position.marketIndex);

      // Long position always use MinPrice. Short position always use MaxPrice
      bool isUseMaxPrice = isLong ? false : true;

      // Get price from oracle
      // @todo - validate price age
      (uint256 priceE30, , ) = IOracleMiddleware(oracle)
        .getLatestPriceWithMarketStatus(
          marketConfig.assetId,
          isUseMaxPrice,
          marketConfig.priceConfidentThreshold,
          0
        );

      // Calculate for priceDelta
      uint256 priceDeltaE30;
      unchecked {
        priceDeltaE30 = position.avgEntryPriceE30 > priceE30
          ? position.avgEntryPriceE30 - priceE30
          : priceE30 - position.avgEntryPriceE30;
      }

      int256 delta = (position.positionSizeE30 * int(priceDeltaE30)) /
        int(position.avgEntryPriceE30);

      if (isLong) {
        delta = priceE30 > position.avgEntryPriceE30 ? delta : -delta;
      } else {
        delta = priceE30 < position.avgEntryPriceE30 ? -delta : delta;
      }

      // If profit then deduct PnL with colleral factor.
      delta = delta > 0
        ? (int(IConfigStorage(configStorage).pnlFactor()) * delta) / 1e18
        : delta;

      // Accumulative current unrealized PnL
      unrealizedPnlE30 += delta;

      unchecked {
        i++;
      }
    }

    return unrealizedPnlE30;
  }

  /// @notice Calculate collateral tokens to value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return collateralValueE30
  function getCollateralValue(
    address _subAccount
  ) public returns (uint256 collateralValueE30) {
    // Get list of current depositing tokens on trader's account
    address[] memory traderTokens = IVaultStorage(vaultStorage).getTraderTokens(
      _subAccount
    );

    // Loop through list of current depositing tokens
    for (uint256 i; i < traderTokens.length; ) {
      address token = traderTokens[i];

      // Get token decimals from ConfigStorage
      uint256 decimals = ERC20(token).decimals();

      // Get collateralFactor from ConfigStorage
      uint256 collateralFactor = IConfigStorage(configStorage)
        .getCollateralTokenConfigs(token)
        .collateralFactor;

      // Get priceConfidentThreshold from ConfigStorage
      uint256 priceConfidenceThreshold = IConfigStorage(configStorage)
        .getMarketConfigByToken(token)
        .priceConfidentThreshold;

      // Get current collateral token balance of trader's account
      uint256 amount = IVaultStorage(vaultStorage).traderBalances(
        _subAccount,
        token
      );

      bool isMaxPrice = false; // @note Collateral value always use Min price
      // Get price from oracle
      // @todo - validate price age
      (uint256 priceE30, , ) = IOracleMiddleware(oracle)
        .getLatestPriceWithMarketStatus(
          token.toBytes32(),
          isMaxPrice,
          priceConfidenceThreshold,
          0
        );

      // Calculate accumulative value of collateral tokens
      // collateal value = (collateral amount * price) * collateralFactor
      // collateralFactor 1 ether = 100%
      collateralValueE30 +=
        (amount * priceE30 * collateralFactor) /
        (10 ** decimals * 1e18);

      unchecked {
        i++;
      }
    }

    return collateralValueE30;
  }

  /// @notice Calculate Intial Margin Requirement from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return imrValueE30 Total imr of trader's account.
  function getIMR(
    address _subAccount
  ) public view returns (uint256 imrValueE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory traderPositions = IPerpStorage(perpStorage)
      .getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < traderPositions.length; ) {
      IPerpStorage.Position memory position = traderPositions[i];

      uint256 size;
      if (position.positionSizeE30 < 0) {
        size = uint(position.positionSizeE30 * -1);
      } else {
        size = uint(position.positionSizeE30);
      }

      // Calculate IMR on position
      imrValueE30 += calculatePositionIMR(size, position.marketIndex);

      unchecked {
        i++;
      }
    }

    return imrValueE30;
  }

  /// @notice Calculate Maintenance Margin Value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return mmrValueE30 Total mmr of trader's account
  function getMMR(
    address _subAccount
  ) public view returns (uint256 mmrValueE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory traderPositions = IPerpStorage(perpStorage)
      .getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < traderPositions.length; ) {
      IPerpStorage.Position memory position = traderPositions[i];

      uint256 size;
      if (position.positionSizeE30 < 0) {
        size = uint(position.positionSizeE30 * -1);
      } else {
        size = uint(position.positionSizeE30);
      }
      // Calculate MMR on position
      mmrValueE30 += calculatePositionMMR(size, position.marketIndex);

      unchecked {
        i++;
      }
    }

    return mmrValueE30;
  }

  /// @notice Calculate for Initial Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return imrE30 The IMR amount required on position size, 30 decimals.
  function calculatePositionIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) public view returns (uint256 imrE30) {
    // Get market config according to position
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    imrE30 = (_positionSizeE30 * marketConfig.initialMarginFraction) / 1e18;
    return imrE30;
  }

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return mmrE30 The MMR amount required on position size, 30 decimals.
  function calculatePositionMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) public view returns (uint256 mmrE30) {
    // Get market config according to position
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    mmrE30 = (_positionSizeE30 * marketConfig.maintenanceMarginFraction) / 1e18;
    return mmrE30;
  }
}
