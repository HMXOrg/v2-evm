// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

contract LiquidationService {
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

  error ITradeService_AccountHealthy();

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage
  /// @param subAccount The sub-account to be liquidated
  function liquidate(address subAccount) external {
    // Get the calculator contract from storage
    ICalculator _calculator = ICalculator(IConfigStorage(configStorage).calculator());

    int256 equity = _calculator.getEquity(subAccount);
    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    if (equity >= 0 || uint256(equity) >= _calculator.getMMR(subAccount)) revert ITradeService_AccountHealthy();

    // Get the list of positions associated with the sub-account
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage).getPositionBySubAccount(subAccount);

    // Liquidate the positions by resetting their value in storage
    _liquidatePosition(_traderPositions);

    // Settles the sub-account by paying off its debt with its collateral
    _settle(subAccount);
  }

  /// @notice Liquidates a list of positions by resetting their value in storage
  /// @param positions The list of positions to be liquidated
  function _liquidatePosition(IPerpStorage.Position[] memory positions) internal {
    // Loop through each position in the list
    for (uint256 i; i < positions.length; ) {
      // Get the current position from the list
      IPerpStorage.Position memory _position = positions[i];

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
  /// @param subAccount The sub-account to be settled
  function _settle(address subAccount) internal {
    // Get contract addresses from storage
    address _configStorage = configStorage;
    address _vaultStorage = vaultStorage;

    // Get instances of the calculator and oracle contracts from storage
    ICalculator calculator = ICalculator(IConfigStorage(_configStorage).calculator());
    IOracleMiddleware oracle = IOracleMiddleware(IConfigStorage(_configStorage).oracle());

    // Get the list of collateral tokens from storage
    address[] memory collateralTokens = IConfigStorage(_configStorage).getCollateralTokens();

    // Get the sub-account's unrealized profit/loss and add the liquidation fee
    uint256 absDebt = abs(calculator.getUnrealizedPnl(subAccount));
    absDebt += IConfigStorage(_configStorage).getLiquidationConfig().liquidationFeeUSDE30;

    // Iterate over each collateral token in the list and pay off debt with its balance
    for (uint256 i = 0; i < collateralTokens.length; ) {
      {
        address collateralToken = collateralTokens[i];

        // Get the sub-account's balance of the collateral token from the vault storage
        uint256 traderBalance = IVaultStorage(_vaultStorage).traderBalances(subAccount, collateralToken);

        // Calculate the amount of debt tokens to repay using the collateral token's price
        uint256 collateralTokenDecimal = ERC20(collateralToken).decimals();
        (uint256 price, ) = oracle.getLatestPrice(
          collateralToken.toBytes32(),
          false,
          IConfigStorage(_configStorage).getCollateralTokenConfigs(collateralToken).priceConfidentThreshold,
          30
        );
        uint256 debtTokenAmount = (absDebt * (10 ** collateralTokenDecimal)) / price;

        // Repay the minimum of the debt token amount and the trader's balance of the collateral token
        uint256 repayAmount = _min(debtTokenAmount, traderBalance);
        absDebt -= (repayAmount * price) / (10 ** collateralTokenDecimal);
        IVaultStorage(_vaultStorage).payPlp(subAccount, collateralToken, repayAmount);
      }

      // Exit the loop if the debt has been fully paid off
      if (absDebt == 0) break;

      unchecked {
        ++i;
      }
    }

    // If the debt has not been fully paid off, add it to the sub-account's bad debt balance in storage
    if (absDebt != 0) IPerpStorage(perpStorage).addBadDebt(subAccount, absDebt);
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
