// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

/// @title Trade Tester
/// @notice This Tester help to check state after user interact with LimitTradeHandler / MarketTradeHandler / TradeService
contract TradeTester is StdAssertions {
  /**
   * States
   */
  IVaultStorage vaultStorage;
  IPerpStorage perpStorage;

  address limitTradeHandler;
  address marketHandler;

  constructor(
    IVaultStorage _vaultStorage,
    IPerpStorage _perpStorage,
    address limitTradeHandler,
    address marketHandler
  ) {
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
  }

  struct TradeExpectedData {
    uint256 xxx;
  }

  struct PerpStateExpectedData {
    uint256 subAccountFee;
  }

  struct GlobalStateExpectedData {
    uint256 reserveValueE30;
  }

  struct GlobalAssetClassExpectedData {
    uint256 reserveValueE30;
    uint256 sumBorrowingRate;
    uint256 lastBorrowingTime;
  }

  struct GlobalMarketExpectedData {
    uint256 lastFundingTime;
    uint256 longPositionSize;
    uint256 longAvgPrice;
    uint256 longOpenInterest;
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
    uint256 shortOpenInterest;
    int256 accumFundingLong;
    int256 accumFundingShort;
    int256 currentFundingRate;
  }

  struct PositionExpectedData {
    uint256 positionSizeE30;
    uint256 avgEntryPriceE30;
    uint256 reserveValueE30;
    uint256 openInterest;
    uint256 lastIncreaseTimestamp;
    int256 realizedPnl;
  }

  /// @notice Assert function when Trader increase position
  /// @dev This function will check
  ///       - PerpStorage's state
  ///         - Sub-account fee
  ///         - Global state
  ///           - Reserve value
  ///         - Global asset class
  ///           - Last borrowing time
  ///           - Borrowing Rate Summation
  ///           - Reserve Value
  ///         - Global market
  ///           - Last funding time
  ///           - Current functing rate
  ///           - Accum funding long
  ///           - Accum funding short
  ///           - Long Position size
  ///           - Long average price
  ///           - Long Open interest
  ///           - Short Position size
  ///           - Short average price
  ///           - Short Open interest
  ///         - Position
  ///           - Last increase timestamp
  ///           - Open interest
  ///           - Reserve value
  ///           - Position size
  ///           - Entry Borrowing rate - global asset class sum borrowing rate
  ///           - Entry funding rate - global market current funding rate
  ///           - Average entry price
  ///       - VaultStorage's state
  ///         - Trader balance
  ///         - Dev fee
  ///         - Funding Fee
  ///         - Fee
  ///         - PLP Liquidity
  ///         - PLP Liquidity Debt value
  function assertTradeInfo() internal {}

  /// @notice Assert function when Trader increase position
  /// @dev This function will check (same with IncreasePosition) and additional below
  ///       - PerpSotage's state
  ///         - Position
  ///           - Realized PnL
  function assert() internal {}
}
