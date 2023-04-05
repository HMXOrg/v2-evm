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
import { Owned } from "@hmx/base/Owned.sol";

// interfaces
import { ILiquidationService } from "./interfaces/ILiquidationService.sol";

contract LiquidationService is ReentrancyGuard, ILiquidationService, Owned {
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public tradeHelper;
  Calculator public calculator;

  /**
   * Events
   */
  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogSetTradeHelper(address indexed oldTradeHelper, address newTradeHelper);

  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  constructor(address _perpStorage, address _vaultStorage, address _configStorage, address _tradeHelper) {
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    tradeHelper = _tradeHelper;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();
    TradeHelper(_tradeHelper).perpStorage();
  }

  function reloadConfig() external nonReentrant onlyOwner {
    // TODO: access control, sanity check, natspec
    // TODO: discuss about this pattern

    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage
  /// @param _subAccount The sub-account to be liquidated
  function liquidate(address _subAccount, address _liquidator) external onlyWhitelistedExecutor {
    // Get the calculator contract from storage
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    int256 _equity = _calculator.getEquity(_subAccount, 0, 0);
    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    if (_equity >= 0 && uint256(_equity) >= _calculator.getMMR(_subAccount))
      revert ILiquidationService_AccountHealthy();

    // Liquidate the positions by resetting their value in storage
    (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee, int256 _unrealizedPnL) = _liquidatePosition(
      _subAccount
    );

    // get profit and fee
    TradeHelper(tradeHelper).increaseCollateral(_subAccount, _unrealizedPnL, _fundingFee);
    // settle fee and loss
    TradeHelper(tradeHelper).decreaseCollateral(
      _subAccount,
      _unrealizedPnL,
      _fundingFee,
      _borrowingFee,
      _tradingFee,
      ConfigStorage(configStorage).getLiquidationConfig().liquidationFeeUSDE30,
      _liquidator
    );

    VaultStorage(vaultStorage).subLossDebt(_subAccount, VaultStorage(vaultStorage).lossDebt(_subAccount));
    VaultStorage(vaultStorage).subTradingFeeDebt(_subAccount, VaultStorage(vaultStorage).tradingFeeDebt(_subAccount));
    VaultStorage(vaultStorage).subBorrowingFeeDebt(
      _subAccount,
      VaultStorage(vaultStorage).borrowingFeeDebt(_subAccount)
    );
    VaultStorage(vaultStorage).subFundingFeeDebt(_subAccount, VaultStorage(vaultStorage).fundingFeeDebt(_subAccount));
  }

  struct LiquidatePositionVars {
    TradeHelper tradeHelper;
    PerpStorage perpStorage;
    ConfigStorage configStorage;
    Calculator calculator;
    OracleMiddleware oracle;
    IPerpStorage.Position position;
    PerpStorage.Market globalMarket;
    ConfigStorage.MarketConfig marketConfig;
    bytes32 positionId;
  }

  /// @notice Liquidates a list of positions by resetting their value in storage
  /// @param _subAccount The sub account of positions
  function _liquidatePosition(
    address _subAccount
  ) internal returns (uint256 tradingFee, uint256 borrowingFee, int256 fundingFee, int256 _unrealizedPnL) {
    LiquidatePositionVars memory _vars;
    // Get the list of position ids associated with the sub-account
    bytes32[] memory positionIds = PerpStorage(perpStorage).getPositionIds(_subAccount);

    _vars.tradeHelper = TradeHelper(tradeHelper);
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = Calculator(calculator);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    uint256 _len = positionIds.length;
    for (uint256 i; i < _len; ) {
      // Get the current position id from the list
      _vars.positionId = positionIds[i];
      _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);
      bool _isLong = _vars.position.positionSizeE30 > 0;

      _vars.marketConfig = _vars.configStorage.getMarketConfigByIndex(_vars.position.marketIndex);

      // Update borrowing rate
      TradeHelper(tradeHelper).updateBorrowingRate(_vars.marketConfig.assetClass);
      // Update funding rate
      TradeHelper(tradeHelper).updateFundingRate(_vars.position.marketIndex);

      {
        (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee) = TradeHelper(tradeHelper).updateFeeStates(
          _subAccount,
          _vars.position,
          abs(_vars.position.positionSizeE30),
          _vars.marketConfig.decreasePositionFeeRateBPS,
          _vars.marketConfig.assetClass,
          _vars.position.marketIndex
        );
        tradingFee += _tradingFee;
        borrowingFee += _borrowingFee;
        fundingFee += _fundingFee;
      }

      _vars.globalMarket = _vars.perpStorage.getMarketByIndex(_vars.position.marketIndex);

      (uint256 _adaptivePrice, , , ) = _vars.oracle.getLatestAdaptivePriceWithMarketStatus(
        _vars.marketConfig.assetId,
        _isLong,
        (int(_vars.globalMarket.longPositionSize) - int(_vars.globalMarket.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _vars.marketConfig.fundingRate.maxSkewScaleUSD,
        0 // liquidation always has no limitedPrice
      );

      // Update global state
      {
        int256 _realizedPnl;
        uint256 absPositionSize = abs(_vars.position.positionSizeE30);
        {
          (bool _isProfit, uint256 _delta) = calculator.getDelta(
            absPositionSize,
            _vars.position.positionSizeE30 > 0,
            _adaptivePrice,
            _vars.position.avgEntryPriceE30,
            _vars.position.lastIncreaseTimestamp
          );
          _realizedPnl = _isProfit ? int256(_delta) : -int256(_delta);
          _unrealizedPnL += _realizedPnl;
        }
        {
          uint256 _nextAvgPrice = _isLong
            ? calculator.calculateMarketAveragePrice(
              int256(_vars.globalMarket.longPositionSize),
              _vars.globalMarket.longAvgPrice,
              -_vars.position.positionSizeE30,
              _adaptivePrice,
              _realizedPnl
            )
            : calculator.calculateMarketAveragePrice(
              -int256(_vars.globalMarket.shortPositionSize),
              _vars.globalMarket.shortAvgPrice,
              -_vars.position.positionSizeE30,
              _adaptivePrice,
              -_realizedPnl
            );

          _vars.perpStorage.updateMarketPrice(_vars.position.marketIndex, _isLong, _nextAvgPrice);
        }
        _vars.perpStorage.decreasePositionSize(_vars.position.marketIndex, _isLong, absPositionSize);
        _vars.perpStorage.decreaseReserved(_vars.marketConfig.assetClass, _vars.position.reserveValueE30);

        // remove the position's value in storage
        _vars.perpStorage.removePositionFromSubAccount(_subAccount, _vars.positionId);
      }

      unchecked {
        ++i;
      }
    }
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

  /**
   * Setter
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ILiquidationService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ILiquidationService_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    VaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external nonReentrant onlyOwner {
    if (_perpStorage == address(0)) revert ILiquidationService_InvalidAddress();

    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
  }

  /// @notice Set new Calculator contract address.
  /// @param _calculator New Calculator contract address.
  function setCalculator(address _calculator) external nonReentrant onlyOwner {
    if (_calculator == address(0)) revert ILiquidationService_InvalidAddress();

    emit LogSetCalculator(address(calculator), _calculator);
    calculator = Calculator(_calculator);

    // Sanity check
    Calculator(_calculator).oracle();
  }

  /// @notice Set new TradeHelper contract address.
  /// @param _tradeHelper New TradeHelper contract address.
  function setTradeHelper(address _tradeHelper) external nonReentrant onlyOwner {
    if (_tradeHelper == address(0)) revert ILiquidationService_InvalidAddress();

    emit LogSetTradeHelper(tradeHelper, _tradeHelper);
    tradeHelper = _tradeHelper;

    // Sanity check
    TradeHelper(_tradeHelper).perpStorage();
  }
}
