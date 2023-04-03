// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

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

  address[] interestTokens;

  constructor(
    IVaultStorage _vaultStorage,
    IPerpStorage _perpStorage,
    address _limitTradeHandler,
    address _marketHandler,
    address[] memory _interestTokens
  ) {
    vaultStorage = _vaultStorage;
    perpStorage = _perpStorage;
    limitTradeHandler = _limitTradeHandler;
    marketHandler = _marketHandler;

    interestTokens = _interestTokens;
  }

  struct PositionExpectedData {
    bytes32 positionId;
    uint256 avgEntryPriceE30;
    uint256 reserveValueE30;
    uint256 lastIncreaseTimestamp;
    int256 positionSizeE30;
    int256 realizedPnl;
  }

  struct GlobalMarketExpectedData {
    uint256 marketIndex;
    uint256 lastFundingTime;
    uint256 longPositionSize;
    uint256 longAvgPrice;
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
    uint256 shortOpenInterest;
    int256 accumFundingLong;
    int256 accumFundingShort;
    int256 currentFundingRate;
  }

  struct GlobalStateExpectedData {
    uint256 reserveValueE30;
    int256 accumFundingLong;
    int256 accumFundingShort;
  }

  struct GlobalAssetClassExpectedData {
    uint256 reserveValueE30;
    uint256 sumBorrowingRate;
    uint256 lastBorrowingTime;
    uint8 assetClassId;
  }

  struct PerpStorageExpectedData {
    int256 subAccountFee;
  }

  struct VaultStorageExpectedData {
    uint256 plpLiquidityDebtUSDE30;
    mapping(address => uint256) plpLiquidity;
    mapping(address => uint256) fees;
    mapping(address => uint256) fundingFee;
    mapping(address => uint256) devFees;
    mapping(address => uint256) traderBalances;
  }

  /// @notice Assert function when Trader increase position
  /// @dev This function will check
  ///     - Position
  ///       - Last increase timestamp
  ///     - Global market
  ///     - PerpStorage
  ///     - VaultStorage
  function assertAfterIncrease(
    address _subAccount,
    PositionExpectedData memory _positionExpectedData,
    GlobalMarketExpectedData memory _globalMarketExpectedData,
    GlobalAssetClassExpectedData memory _globalAssetClassExpectedData,
    GlobalStateExpectedData memory _globalStateExpectedData,
    PerpStorageExpectedData memory _perpStorageExpectedData,
    VaultStorageExpectedData storage _vaultStorageExpectedData
  ) internal {
    // Check position info
    IPerpStorage.Position memory _position = _assertPosition(
      _positionExpectedData,
      _globalMarketExpectedData,
      _globalAssetClassExpectedData
    );

    // This assert only increase position
    assertEq(_position.lastIncreaseTimestamp, block.timestamp, "Last increase timestamp");

    // Check market
    _assertMarket(_globalMarketExpectedData);

    // Check perp storage
    _assertPerpStorage(_subAccount, _perpStorageExpectedData, _globalAssetClassExpectedData, _globalStateExpectedData);
    _assertVaultStorage(_subAccount, _vaultStorageExpectedData);
  }

  /// @notice Assert function when Trader decrease position
  /// @dev This function will check
  ///     - Position
  ///       - Realized PnL
  ///     - Global market
  ///     - PerpStorage
  ///     - VaultStorage
  function assertAfterDecrease(
    address _subAccount,
    PositionExpectedData memory _positionExpectedData,
    GlobalMarketExpectedData memory _globalMarketExpectedData,
    GlobalAssetClassExpectedData memory _globalAssetClassExpectedData,
    GlobalStateExpectedData memory _globalStateExpectedData,
    PerpStorageExpectedData memory _perpStorageExpectedData,
    VaultStorageExpectedData storage _vaultStorageExpectedData
  ) internal {
    // Check position info
    IPerpStorage.Position memory _position = _assertPosition(
      _positionExpectedData,
      _globalMarketExpectedData,
      _globalAssetClassExpectedData
    );

    // This assert only increase position
    assertEq(_position.realizedPnl, _positionExpectedData.realizedPnl, "Last increase timestamp");

    // Check market
    _assertMarket(_globalMarketExpectedData);
    _assertPerpStorage(_subAccount, _perpStorageExpectedData, _globalAssetClassExpectedData, _globalStateExpectedData);
    _assertVaultStorage(_subAccount, _vaultStorageExpectedData);
  }

  /// @notice Assert position info
  /// @dev This function will check
  ///       - Average entry price
  ///       - Reserve value
  ///       - Position size
  ///       - Entry Borrowing rate - global asset class sum borrowing rate
  ///       - Entry funding rate - global market current funding rate
  function _assertPosition(
    PositionExpectedData memory _positionExpectedData,
    GlobalMarketExpectedData memory _globalMarketExpectedData,
    GlobalAssetClassExpectedData memory _globalAssetClassExpectedData
  ) internal returns (IPerpStorage.Position memory _position) {
    _position = perpStorage.getPositionById(_positionExpectedData.positionId);

    assertEq(_position.positionSizeE30, _positionExpectedData.positionSizeE30, "Position size");
    assertEq(_position.avgEntryPriceE30, _positionExpectedData.avgEntryPriceE30, "Position Average Price");
    assertEq(_position.reserveValueE30, _positionExpectedData.reserveValueE30, "Position Reserve");

    assertEq(_position.entryBorrowingRate, _globalAssetClassExpectedData.sumBorrowingRate, "Entry Borrowing rate");
    assertEq(_position.entryFundingRate, _globalMarketExpectedData.currentFundingRate, "Entry Funding rate");
  }

  /// @notice Assert Market
  /// @dev This function will check
  ///       - Last funding time
  ///       - Current funding rate
  ///       - Long Position size
  ///       - Long average price
  ///       - Short Position size
  ///       - Short average price
  function _assertMarket(GlobalMarketExpectedData memory _globalMarketExpectedData) internal {
    IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(
      _globalMarketExpectedData.marketIndex
    );

    assertEq(_globalMarket.longPositionSize, _globalMarketExpectedData.longPositionSize, "Long Position size");
    assertEq(_globalMarket.longAvgPrice, _globalMarketExpectedData.longAvgPrice, "Long Average Price");

    assertEq(_globalMarket.shortPositionSize, _globalMarketExpectedData.shortPositionSize, "Short Position size");
    assertEq(_globalMarket.shortAvgPrice, _globalMarketExpectedData.shortAvgPrice, "Short Average Price");

    assertEq(_globalMarket.currentFundingRate, _globalMarketExpectedData.currentFundingRate, "Current Funding Rate");
    assertEq(_globalMarket.lastFundingTime, _globalMarketExpectedData.lastFundingTime, "Last Funding Time");
  }

  /// @notice Assert PerpStorage
  /// @dev This function will check
  ///       - Sub-account fee
  ///       - Global asset class
  ///         - Last borrowing time
  ///         - Borrowing Rate Summation
  ///         - Reserve Value
  ///       - Global state
  ///         - Reserve value
  function _assertPerpStorage(
    address _subAccount,
    PerpStorageExpectedData memory _perpStorageExpectedData,
    GlobalAssetClassExpectedData memory _globalAssetClassExpectedData,
    GlobalStateExpectedData memory _globalStateExpectedData
  ) internal {
    IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(
      _globalAssetClassExpectedData.assetClassId
    );
    IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();

    // Check global asset class
    assertEq(_globalAssetClass.reserveValueE30, _globalAssetClassExpectedData.reserveValueE30, "Global Asset Reserve");
    assertEq(
      _globalAssetClass.sumBorrowingRate,
      _globalAssetClassExpectedData.sumBorrowingRate,
      "Global Asset Borrowing Rate"
    );
    assertEq(
      _globalAssetClass.lastBorrowingTime,
      _globalAssetClassExpectedData.lastBorrowingTime,
      "Global Asset Last Borrowing time"
    );

    // Check global reserve
    assertEq(_globalState.reserveValueE30, _globalStateExpectedData.reserveValueE30, "Global Reserve");
  }

  /// @notice Assert Vault info
  /// @dev This function will check
  ///       - Trader balance
  ///       - Dev fee
  ///       - Funding Fee
  ///       - Fee
  ///       - PLP Liquidity
  ///       - PLP Liquidity Debt value
  function _assertVaultStorage(address _subAccount, VaultStorageExpectedData storage _expectedData) internal {
    assertEq(vaultStorage.plpLiquidityDebtUSDE30(), _expectedData.plpLiquidityDebtUSDE30);

    uint256 _len = interestTokens.length;
    address _token;
    for (uint256 _i; _i < _len; ) {
      _token = interestTokens[_i];

      assertEq(vaultStorage.plpLiquidity(_token), _expectedData.plpLiquidity[_token], "PLP Liquidity");
      assertEq(vaultStorage.protocolFees(_token), _expectedData.fees[_token], "Protocol Fee");
      assertEq(vaultStorage.fundingFeeReserve(_token), _expectedData.fundingFee[_token], "Funding Fee");
      assertEq(vaultStorage.devFees(_token), _expectedData.devFees[_token], "Dev Fee");
      assertEq(
        vaultStorage.traderBalances(_subAccount, _token),
        _expectedData.traderBalances[_token],
        "Trader balance"
      );

      unchecked {
        ++_i;
      }
    }
  }
}
