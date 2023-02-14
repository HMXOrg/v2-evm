// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

// Interfaces
import { ICalculator } from "./interfaces/ICalculator.sol";
import { IOracleAdapter } from "../oracle/interfaces/IOracleAdapter.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";

contract Calculator is Ownable, ICalculator {
  // using libs for type
  using AddressUtils for address;

  address public oracle;
  address public vaultStorage;
  address public configStorage;
  address public perpStorage;

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
    if (_oracle == address(0)) revert InvalidAddress();
    oracle = _oracle;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    perpStorage = _perpStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTERs  ///////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setOracle(address _oracle) external onlyOwner {
    if (_oracle == address(0)) revert InvalidAddress();
    address oldOracle = _oracle;
    oracle = _oracle;
    emit LogSetOracle(oldOracle, oracle);
  }

  function setVaultStorage(address _vaultStorage) external onlyOwner {
    if (_vaultStorage == address(0)) revert InvalidAddress();
    address oldVaultStorage = _vaultStorage;
    vaultStorage = _vaultStorage;
    emit LogSetVaultStorage(oldVaultStorage, vaultStorage);
  }

  function SetConfigStorage(address _configStorage) external onlyOwner {
    if (_configStorage == address(0)) revert InvalidAddress();
    address oldConfigStorage = _configStorage;
    configStorage = _configStorage;
    emit LogSetConfigStorage(oldConfigStorage, configStorage);
  }

  function SetPerpStorage(address _perpStorage) external onlyOwner {
    if (_perpStorage == address(0)) revert InvalidAddress();
    address oldPerpStorage = _perpStorage;
    perpStorage = _perpStorage;
    emit LogSetPerpStorage(oldPerpStorage, perpStorage);
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATORs
  ////////////////////////////////////////////////////////////////////////////////////

  // Equity = Sum(tokens' Values) + Sum(Pnl) - Unrealized Borrowing Fee - Unrealized Funding Fee
  function getEquity(
    address _trader,
    bool isUseMaxPrice
  ) external returns (uint equityValueE30) {
    // calculate trader's account value from all trader's depositing collateral tokens
    // @todo - implementing
    address[] memory traderTokens = IVaultStorage(vaultStorage).getTraderTokens(
      _trader
    );

    // calculate collateral value on trader's sub account
    uint collateralValueE30;
    {
      for (uint i; i < traderTokens.length; ) {
        address token = traderTokens[i];
        uint256 decimals = IConfigStorage(configStorage)
          .getCollateralTokenConfigs(token)
          .decimals;

        uint256 priceConfidentThreshold = IConfigStorage(configStorage)
          .getMarketConfigByAssetId(token.toBytes32())
          .priceConfidentThreshold;

        uint amount = IVaultStorage(vaultStorage).traderBalances(
          _trader,
          token
        );

        (uint priceE30, ) = IOracleAdapter(oracle).getLatestPrice(
          token.toBytes32(),
          isUseMaxPrice,
          priceConfidentThreshold
        );

        collateralValueE30 += (amount * priceE30) / 10 ** decimals;

        unchecked {
          i++;
        }
      }
    }

    // @todo - calculate borrowing fee
    // @todo - calculate funding fee

    // calculate unrealized PnL on trader's sub account
    int unrealizedPnlValueE30;
    {
      IPerpStorage.Position[] memory traderPositions = IPerpStorage(perpStorage)
        .getPositionBySubAccount(_trader);
      for (uint i; i < traderPositions.length; ) {
        IPerpStorage.Position memory position = traderPositions[i];

        // get market's price
        IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
          configStorage
        ).getMarketConfigByIndex(position.marketIndex);

        (uint priceE30, ) = IOracleAdapter(oracle).getLatestPrice(
          marketConfig.assetId,
          isUseMaxPrice,
          marketConfig.priceConfidentThreshold
        );

        // calculate price delta
        int priceDeltaE30 = int(position.avgEntryPriceE30 - priceE30);
        // if price delta is negative(-) then
        // - short positon must return negative(-) in Pnl
        // - long positon must return positive(+) in Pnl
        // if price delta is positive(+) then
        // - short positon must return positive(+) in Pnl
        // - long positon must return negative(-) in Pnl

        // unrealizedPnlValueE30 +=
        //   (priceDeltaE30 * position.positionSizeE30) /
        //   position.avgEntryPriceE30;

        unchecked {
          i++;
        }
      }
    }
  }
}
