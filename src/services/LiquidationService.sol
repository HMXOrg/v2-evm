// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contracts
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

// interfaces
import { ILiquidationService } from "./interfaces/ILiquidationService.sol";

contract LiquidationService is ReentrancyGuard, ILiquidationService {
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public tradeHelper;

  Calculator calculator;

  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  constructor(address _perpStorage, address _vaultStorage, address _configStorage, address _tradeHelper) {
    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    tradeHelper = _tradeHelper;
  }

  function reloadConfig() external {
    // TODO: access control, sanity check, natspec
    // TODO: discuss about this pattern

    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage
  /// @param _subAccount The sub-account to be liquidated
  function liquidate(address _subAccount) external nonReentrant onlyWhitelistedExecutor {
    // Get the calculator contract from storage
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    int256 _equity = _calculator.getEquity(_subAccount, 0, 0);

    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    if (_equity >= 0 && uint256(_equity) >= _calculator.getMMR(_subAccount))
      revert ILiquidationService_AccountHealthy();

    // Liquidate the positions by resetting their value in storage
    int256 _unrealizedPnL = _liquidatePosition(_subAccount);

    // Settles the sub-account by paying off its debt with its collateral
    _settlePnl(_subAccount, abs(_unrealizedPnL));
  }

  struct LiquidatePositionVars {
    TradeHelper tradeHelper;
    PerpStorage perpStorage;
    ConfigStorage configStorage;
    Calculator calculator;
    OracleMiddleware oracle;
    IPerpStorage.Position position;
    PerpStorage.GlobalMarket globalMarket;
    ConfigStorage.MarketConfig marketConfig;
    bytes32 positionId;
  }

  /// @notice Liquidates a list of positions by resetting their value in storage
  /// @param _subAccount The sub account of positions
  function _liquidatePosition(address _subAccount) internal returns (int256 _unrealizedPnL) {
    LiquidatePositionVars memory _vars;
    // Get the list of position ids associated with the sub-account
    bytes32[] memory positionIds = PerpStorage(perpStorage).getPositionIds(_subAccount);

    _vars.tradeHelper = TradeHelper(tradeHelper);
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = Calculator(calculator);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    uint256 _len = positionIds.length;
    // Loop through each position in the list
    for (uint256 i; i < _len; ) {
      // Get the current position id from the list
      _vars.positionId = positionIds[i];
      _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);

      _vars.marketConfig = _vars.configStorage.getMarketConfigByIndex(_vars.position.marketIndex);

      // Update borrowing rate
      TradeHelper(tradeHelper).updateBorrowingRate(_vars.marketConfig.assetClass, 0, 0);
      // Update funding rate
      TradeHelper(tradeHelper).updateFundingRate(_vars.position.marketIndex, 0);

      // Settle
      // - trading fees
      // - borrowing fees
      // - funding fees
      TradeHelper(tradeHelper).settleAllFees(
        _vars.position,
        uint256(_vars.position.positionSizeE30 > 0 ? _vars.position.positionSizeE30 : -_vars.position.positionSizeE30),
        _vars.marketConfig.decreasePositionFeeRateBPS,
        _vars.marketConfig.assetClass,
        _vars.position.marketIndex
      );

      bool _isLong = _vars.position.positionSizeE30 > 0;

      _vars.globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_vars.position.marketIndex);

      (uint256 _priceE30, , , , ) = _vars.oracle.getLatestAdaptivePriceWithMarketStatus(
        _vars.marketConfig.assetId,
        _isLong,
        (int(_vars.globalMarket.longOpenInterest) - int(_vars.globalMarket.shortOpenInterest)),
        _isLong ? -int(_vars.position.positionSizeE30) : int(_vars.position.positionSizeE30),
        _vars.marketConfig.fundingRate.maxSkewScaleUSD
      );

      // Update global state
      {
        int256 _realizedPnl;
        uint256 absPositionSize = abs(_vars.position.positionSizeE30);
        {
          (bool _isProfit, uint256 _delta) = calculator.getDelta(
            absPositionSize,
            _vars.position.positionSizeE30 > 0,
            _priceE30,
            _vars.position.avgEntryPriceE30,
            _vars.position.lastIncreaseTimestamp
          );
          _realizedPnl = _isProfit ? int256(_delta) : -int256(_delta);
          _unrealizedPnL += _realizedPnl;
        }
        {
          uint256 _nextAvgPrice = _isLong
            ? calculator.calculateLongAveragePrice(
              _vars.globalMarket,
              _priceE30,
              -int256(_vars.position.positionSizeE30),
              _realizedPnl
            )
            : calculator.calculateShortAveragePrice(
              _vars.globalMarket,
              _priceE30,
              int256(_vars.position.positionSizeE30),
              _realizedPnl
            );
          _vars.perpStorage.updateGlobalMarketPrice(_vars.position.marketIndex, _isLong, _nextAvgPrice);
        }
        _vars.perpStorage.decreaseOpenInterest(
          _vars.position.marketIndex,
          _isLong,
          absPositionSize,
          _vars.position.openInterest
        );
        _vars.perpStorage.decreaseReserved(_vars.marketConfig.assetClass, _vars.position.openInterest);

        // remove the position's value in storage
        _vars.perpStorage.removePositionFromSubAccount(_subAccount, _vars.positionId);
      }

      unchecked {
        ++i;
      }
    }
  }

  struct SettleStruct {
    address configStorage;
    address vaultStorage;
  }

  /// @notice Settles the sub-account by paying off its debt with its collateral
  /// @param _subAccount The sub-account to be settled
  function _settlePnl(address _subAccount, uint256 _unrealizedPnL) internal {
    SettleStruct memory _vars;
    // Get contract addresses from storage
    _vars.configStorage = configStorage;
    _vars.vaultStorage = vaultStorage;

    // Get instances of the oracle contracts from storage
    OracleMiddleware _oracle = OracleMiddleware(ConfigStorage(_vars.configStorage).oracle());

    // Get the list of collateral tokens from storage
    address[] memory _collateralTokens = ConfigStorage(_vars.configStorage).getCollateralTokens();

    // Get the sub-account's unrealized profit/loss and add the liquidation fee
    uint256 _absDebt = _unrealizedPnL;
    _absDebt += ConfigStorage(_vars.configStorage).getLiquidationConfig().liquidationFeeUSDE30;

    uint256 _len = _collateralTokens.length;
    // Iterate over each collateral token in the list and pay off debt with its balance
    for (uint256 i = 0; i < _len; ) {
      address _collateralToken = _collateralTokens[i];

      // Calculate the amount of debt tokens to repay using the collateral token's price
      uint256 _collateralTokenDecimal = ERC20(_collateralToken).decimals();
      (uint256 _price, ) = _oracle.getLatestPrice(
        ConfigStorage(_vars.configStorage).tokenAssetIds(_collateralToken),
        false
      );

      // Get the sub-account's balance of the collateral token from the vault storage and calculate value
      uint256 _traderBalanceValue = (VaultStorage(_vars.vaultStorage).traderBalances(_subAccount, _collateralToken) *
        _price) / (10 ** _collateralTokenDecimal);

      // Repay the minimum of the debt token amount and the trader's balance of the collateral token
      uint256 _repayValue = _min(_absDebt, _traderBalanceValue);
      _absDebt -= _repayValue;
      VaultStorage(_vars.vaultStorage).payPlp(
        _subAccount,
        _collateralToken,
        (_repayValue * (10 ** _collateralTokenDecimal)) / _price
      );

      // Exit the loop if the debt has been fully paid off
      if (_absDebt == 0) break;

      unchecked {
        ++i;
      }
    }

    // If the debt has not been fully paid off, add it to the sub-account's bad debt balance in storage
    if (_absDebt != 0) PerpStorage(perpStorage).addBadDebt(_subAccount, _absDebt);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}
