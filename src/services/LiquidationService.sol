// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { ILiquidationService } from "./interfaces/ILiquidationService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

contract LiquidationService is ILiquidationService {
  using AddressUtils for address;

  address public perpStorage;
  address public vaultStorage;
  address public configStorage;

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    // @todo - sanity check
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
  }

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage
  /// @param _subAccount The sub-account to be liquidated
  function liquidate(address _subAccount) external {
    // Get the calculator contract from storage
    ICalculator _calculator = ICalculator(IConfigStorage(configStorage).calculator());

    int256 _equity = _calculator.getEquity(_subAccount);
    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    if (_equity >= 0 && uint256(_equity) >= _calculator.getMMR(_subAccount))
      revert ILiquidationService_AccountHealthy();

    // Get the list of positions associated with the sub-account
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Settles the sub-account by paying off its debt with its collateral
    _settle(_subAccount);

    // Liquidate the positions by resetting their value in storage
    _liquidatePosition(_traderPositions);
  }

  /// @notice Liquidates a list of positions by resetting their value in storage
  /// @param _positions The list of positions to be liquidated
  function _liquidatePosition(IPerpStorage.Position[] memory _positions) internal {
    // Loop through each position in the list
    IPerpStorage.Position memory _position;
    uint256 _len = _positions.length;
    for (uint256 i; i < _len; ) {
      // Get the current position from the list
      _position = _positions[i];

      // Reset the position's value in storage
      IPerpStorage(perpStorage).resetPosition(
        _getPositionId(_getSubAccount(_position.primaryAccount, _position.subAccountId), _position.marketIndex)
      );

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
    IOracleMiddleware _oracle = IOracleMiddleware(IConfigStorage(_configStorage).oracle());

    // Get the list of collateral tokens from storage
    address[] memory _collateralTokens = IConfigStorage(_configStorage).getCollateralTokens();

    // Get the sub-account's unrealized profit/loss and add the liquidation fee
    uint256 _absDebt = abs(ICalculator(IConfigStorage(_configStorage).calculator()).getUnrealizedPnl(_subAccount));
    _absDebt += IConfigStorage(_configStorage).getLiquidationConfig().liquidationFeeUSDE30;

    uint256 _len = _collateralTokens.length;
    // Iterate over each collateral token in the list and pay off debt with its balance
    for (uint256 i = 0; i < _len; ) {
      address _collateralToken = _collateralTokens[i];

      // Calculate the amount of debt tokens to repay using the collateral token's price
      uint256 _collateralTokenDecimal = ERC20(_collateralToken).decimals();
      (uint256 _price, ) = _oracle.getLatestPrice(
        _collateralToken.toBytes32(),
        false,
        IConfigStorage(_configStorage).getCollateralTokenConfigs(_collateralToken).priceConfidentThreshold,
        30
      );

      // Get the sub-account's balance of the collateral token from the vault storage and calculate value
      uint256 _traderBalanceValue = (IVaultStorage(_vaultStorage).traderBalances(_subAccount, _collateralToken) *
        _price) / (10 ** _collateralTokenDecimal);

      // Repay the minimum of the debt token amount and the trader's balance of the collateral token
      uint256 _repayValue = _min(_absDebt, _traderBalanceValue);
      _absDebt -= _repayValue;
      IVaultStorage(_vaultStorage).payPlp(
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
    if (_absDebt != 0) IPerpStorage(perpStorage).addBadDebt(_subAccount, _absDebt);
  }

  function _getSubAccount(address _primary, uint256 _subAccountId) internal pure returns (address) {
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
