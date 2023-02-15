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
    if (_oracle == address(0)) revert ICalculator_InvalidAddress();
    oracle = _oracle;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    perpStorage = _perpStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTERs  ///////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setOracle(address _oracle) external onlyOwner {
    if (_oracle == address(0)) revert ICalculator_InvalidAddress();
    address oldOracle = _oracle;
    oracle = _oracle;
    emit LogSetOracle(oldOracle, oracle);
  }

  function setVaultStorage(address _vaultStorage) external onlyOwner {
    if (_vaultStorage == address(0)) revert ICalculator_InvalidAddress();
    address oldVaultStorage = _vaultStorage;
    vaultStorage = _vaultStorage;
    emit LogSetVaultStorage(oldVaultStorage, vaultStorage);
  }

  function SetConfigStorage(address _configStorage) external onlyOwner {
    if (_configStorage == address(0)) revert ICalculator_InvalidAddress();
    address oldConfigStorage = _configStorage;
    configStorage = _configStorage;
    emit LogSetConfigStorage(oldConfigStorage, configStorage);
  }

  function SetPerpStorage(address _perpStorage) external onlyOwner {
    if (_perpStorage == address(0)) revert ICalculator_InvalidAddress();
    address oldPerpStorage = _perpStorage;
    perpStorage = _perpStorage;
    emit LogSetPerpStorage(oldPerpStorage, perpStorage);
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATORs
  ////////////////////////////////////////////////////////////////////////////////////

  // Equity = Sum(tokens' Values) + Sum(Pnl) - Unrealized Borrowing Fee - Unrealized Funding Fee
  function getAccountInfo(
    address _trader
  ) external returns (uint equityValueE30, uint imrValueE30, uint mmrValueE30) {
    // calculate trader's account value from all trader's depositing collateral tokens
    address[] memory traderTokens = IVaultStorage(vaultStorage).getTraderTokens(
      _trader
    );

    // calculate collateral value on trader's sub account
    uint collateralValueE30;
    {
      for (uint i; i < traderTokens.length; ) {
        address token = traderTokens[i];
        uint decimals = IConfigStorage(configStorage)
          .getCollateralTokenConfigs(token)
          .decimals;

        uint priceConfidentThreshold = IConfigStorage(configStorage)
          .getMarketConfigByAssetId(token.toBytes32())
          .priceConfidentThreshold;

        uint amount = IVaultStorage(vaultStorage).traderBalances(
          _trader,
          token
        );

        (uint priceE30, ) = IOracleAdapter(oracle).getLatestPrice(
          token.toBytes32(),
          false,
          priceConfidentThreshold
        );

        collateralValueE30 += (amount * priceE30) / 10 ** decimals;

        unchecked {
          i++;
        }
      }
    }

    // Calculate unrealized PnL on trader's sub account
    int unrealizedPnlValueE30;
    {
      IPerpStorage.Position[] memory traderPositions = IPerpStorage(perpStorage)
        .getPositionBySubAccount(_trader);

      // Loop through trader's positions
      for (uint i; i < traderPositions.length; ) {
        IPerpStorage.Position memory position = traderPositions[i];
        bool isLong = position.positionSizeE30 > 0 ? true : false;

        if (position.avgEntryPriceE30 == 0)
          revert ICalculator_InvalidAveragePrice();

        // Get market's price
        IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
          configStorage
        ).getMarketConfigByIndex(position.marketIndex);

        // Long position always use MinPrice. Short position always use MaxPrice
        bool isUseMaxPrice = isLong ? false : true;

        (uint priceE30, ) = IOracleAdapter(oracle).getLatestPrice(
          marketConfig.assetId,
          isUseMaxPrice,
          marketConfig.priceConfidentThreshold
        );

        // Calculate for priceDelta
        uint priceDeltaE30;
        unchecked {
          priceDeltaE30 = position.avgEntryPriceE30 > priceE30
            ? position.avgEntryPriceE30 - priceE30
            : priceE30 - position.avgEntryPriceE30;
        }
        int delta = (position.positionSizeE30 * int(priceDeltaE30)) /
          int(position.avgEntryPriceE30);

        if (isLong) {
          delta = priceE30 > position.avgEntryPriceE30 ? delta : -delta;
        } else {
          delta = priceE30 < position.avgEntryPriceE30 ? delta : -delta;
        }

        // If profit then deduct PnL with colleral factor.
        delta += delta > 0
          ? (int(IConfigStorage(configStorage).pnlFactor()) * delta) / 1e18
          : delta;

        // Accumulative current unrealized PnL
        unrealizedPnlValueE30 += delta;

        // Calculate IMR on position
        imrValueE30 += calIMR(
          uint(position.positionSizeE30),
          position.marketIndex
        );

        // Calculate MMR on position
        mmrValueE30 += calIMR(
          uint(position.positionSizeE30),
          position.marketIndex
        );

        unchecked {
          i++;
        }
      }
    }

    // @todo - calculate borrowing fee
    // @todo - calculate funding fee

    // Sum all asset's values
    equityValueE30 += collateralValueE30;
    if (unrealizedPnlValueE30 > 0) {
      equityValueE30 += uint(unrealizedPnlValueE30);
    } else {
      equityValueE30 -= uint(unrealizedPnlValueE30);
    }
  }

  function calIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) public view returns (uint256 imr) {
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    imr = (_positionSizeE30 * marketConfig.initialMarginFraction) / 1e18;
  }

  function calMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) public view returns (uint256 mmr) {
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    mmr = (_positionSizeE30 * marketConfig.maintenanceMarginFraction) / 1e18;
  }
}
