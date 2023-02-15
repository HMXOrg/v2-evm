// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICalculator {
  // ERRORs
  error ICalculator_InvalidAddress();
  error ICalculator_InvalidAveragePrice();

  /// @notice Calculate for Initial Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return imrE30 The IMR amount required on position size, 30 decimals.
  function calIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) external view returns (uint256 imrE30);

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return mmrE30 The MMR amount required on position size, 30 decimals.
  function calMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) external view returns (uint256 mmrE30);
}
