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

// interfaces
import { ILiquidationService } from "./interfaces/ILiquidationService.sol";

contract LiquidationService is ReentrancyGuard, ILiquidationService {
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public tradeHelper;

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

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage
  /// @param _subAccount The sub-account to be liquidated
  function liquidate(address _subAccount) external nonReentrant onlyWhitelistedExecutor {
    // Get the calculator contract from storage
    Calculator _calculator = Calculator(ConfigStorage(configStorage).calculator());

    int256 _equity = _calculator.getEquity(_subAccount, 0, 0);
    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    if (_equity >= 0 && uint256(_equity) >= _calculator.getMMR(_subAccount))
      revert ILiquidationService_AccountHealthy();

    // Get the list of position ids associated with the sub-account
    // bytes32[] memory _positionIds = PerpStorage(perpStorage).getPositionIds(_subAccount);
    IPerpStorage.Position[] memory _positions = PerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Settles the sub-account by paying off its debt with its collateral
    _settle(_subAccount);

    // Liquidate the positions by resetting their value in storage
    _liquidatePosition(_subAccount, _positions);
  }

  /// @notice Liquidates a list of positions by resetting their value in storage
  /// @param _subAccount The sub account of positions
  /// @param _positions The list of positions to be liquidated
  function _liquidatePosition(address _subAccount, IPerpStorage.Position[] memory _positions) internal {
    // Loop through each position in the list
    IPerpStorage.Position memory _position;
    uint256 _len = _positions.length;
    for (uint256 i; i < _len; ) {
      // Get the current position id from the list
      _position = _positions[i];

      // Calculator(ConfigStorage(configStorage).calculator());

      ConfigStorage.MarketConfig memory _marketConfig = ConfigStorage(configStorage).getMarketConfigByIndex(
        _position.marketIndex
      );

      // Update borrowing rate
      TradeHelper(tradeHelper).updateBorrowingRate(_marketConfig.assetClass, 0, 0);

      // Update funding rate
      TradeHelper(tradeHelper).updateFundingRate(_position.marketIndex, 0);

      TradeHelper(tradeHelper).collectMarginFee(
        _subAccount,
        uint256(_position.positionSizeE30 > 0 ? _position.positionSizeE30 : -_position.positionSizeE30),
        _marketConfig.assetClass,
        _position.reserveValueE30,
        _position.entryBorrowingRate,
        _marketConfig.decreasePositionFeeRateBPS
      );

      TradeHelper(tradeHelper).settleMarginFee(_subAccount);

      // Collect funding fee
      TradeHelper(tradeHelper).collectFundingFee(
        _subAccount,
        _marketConfig.assetClass,
        _position.marketIndex,
        _position.positionSizeE30,
        _position.entryFundingRate
      );

      TradeHelper(tradeHelper).settleFundingFee(_subAccount, 0, 0);

      // Reset the position's value in storage
      PerpStorage(perpStorage).removePositionFromSubAccount(_subAccount, _positionId);

      unchecked {
        ++i;
      }
    }
  }

  /// @notice Settles the sub-account by paying off its debt with its collateral
  /// @param _subAccount The sub-account to be settled
  function _settle(address _subAccount) internal {
    // Get contract addresses from storage
    address _configStorage = configStorage;
    address _vaultStorage = vaultStorage;

    // Get instances of the oracle contracts from storage
    OracleMiddleware _oracle = OracleMiddleware(ConfigStorage(_configStorage).oracle());

    // Get the list of collateral tokens from storage
    address[] memory _collateralTokens = ConfigStorage(_configStorage).getCollateralTokens();

    // Get the sub-account's unrealized profit/loss and add the liquidation fee
    uint256 _absDebt = abs(Calculator(ConfigStorage(_configStorage).calculator()).getUnrealizedPnl(_subAccount, 0, 0));
    _absDebt += ConfigStorage(_configStorage).getLiquidationConfig().liquidationFeeUSDE30;

    uint256 _len = _collateralTokens.length;
    // Iterate over each collateral token in the list and pay off debt with its balance
    for (uint256 i = 0; i < _len; ) {
      address _collateralToken = _collateralTokens[i];

      // Calculate the amount of debt tokens to repay using the collateral token's price
      uint256 _collateralTokenDecimal = ERC20(_collateralToken).decimals();
      (uint256 _price, ) = _oracle.getLatestPrice(ConfigStorage(_configStorage).tokenAssetIds(_collateralToken), false);

      // Get the sub-account's balance of the collateral token from the vault storage and calculate value
      uint256 _traderBalanceValue = (VaultStorage(_vaultStorage).traderBalances(_subAccount, _collateralToken) *
        _price) / (10 ** _collateralTokenDecimal);

      // Repay the minimum of the debt token amount and the trader's balance of the collateral token
      uint256 _repayValue = _min(_absDebt, _traderBalanceValue);
      _absDebt -= _repayValue;
      VaultStorage(_vaultStorage).payPlp(
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
