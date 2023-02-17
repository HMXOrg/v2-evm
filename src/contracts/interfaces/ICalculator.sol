// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICalculator {
  // ERRORs
  error ICalculator_InvalidAddress();
  error ICalculator_InvalidAveragePrice();

  /// @notice Calculate for Initial Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _imrE30 The IMR amount required on position size, 30 decimals.
  function calculatePositionIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) external view returns (uint256 _imrE30);

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _mmrE30 The MMR amount required on position size, 30 decimals.
  function calculatePositionMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) external view returns (uint256 _mmrE30);

  /// @notice Calculate for value on trader's account including Equity, IMR and MMR.
  /// @dev Equity = Sum(collateral tokens' Values) + Sum(unrealized PnL) - Unrealized Borrowing Fee - Unrealized Funding Fee
  /// @param _subAccount Trader account's address.
  /// @return _equityValueE30 Total equity of trader's account.
  function getEquity(
    address _subAccount
  ) external returns (uint256 _equityValueE30);

  // @todo - Add Description
  function getUnrealizedPnl(
    address _subAccount
  ) external view returns (int _unrealizedPnlE30);

  // @todo - Add Description
  /// @return _imrValueE30 Total imr of trader's account.
  function getIMR(
    address _subAccount
  ) external view returns (uint256 _imrValueE30);

  // @todo - Add Description
  /// @return _mmrValueE30 Total mmr of trader's account
  function getMMR(
    address _subAccount
  ) external view returns (uint256 _mmrValueE30);
}
