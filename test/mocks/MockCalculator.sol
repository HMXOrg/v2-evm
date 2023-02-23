// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ICalculator } from "../../src/contracts/interfaces/ICalculator.sol";
import { IConfigStorage } from "../../src/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../../src/storages/interfaces/IVaultStorage.sol";

contract MockCalculator is ICalculator {
  mapping(address => uint256) equitiesOf;
  mapping(address => uint256) imrOf;
  mapping(address => uint256) mmrOf;
  mapping(address => int256) unrealizedPnlOf;
  uint256 freeCollateral;

  uint256 aum;
  uint256 plpValue;
  uint256 nextBorrowingRate;

  address public oracle;

  constructor(address _oracle) {
    oracle = _oracle;
  }

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function setEquity(address _subAccount, uint256 _mockEquity) external {
    equitiesOf[_subAccount] = _mockEquity;
  }

  function setIMR(address _subAccount, uint256 _mockImr) external {
    imrOf[_subAccount] = _mockImr;
  }

  function setMMR(address _subAccount, uint256 _mockMmr) external {
    mmrOf[_subAccount] = _mockMmr;
  }

  function setUnrealizedPnl(address _subAccount, int256 _mockUnrealizedPnl) external {
    unrealizedPnlOf[_subAccount] = _mockUnrealizedPnl;
  }

  function setAUM(uint256 _aum) external {
    aum = _aum;
  }

  function setFreeCollateral(uint256 _mockFreeCollateral) external {
    freeCollateral = _mockFreeCollateral;
  }

  function setPLPValue(uint256 _mockPLPValue) external {
    plpValue = _mockPLPValue;
  }

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  function getEquity(address _subAccount) external view returns (uint256) {
    return equitiesOf[_subAccount];
  }

  // @todo - Add Description
  function getUnrealizedPnl(address _subAccount) external view returns (int256) {
    return unrealizedPnlOf[_subAccount];
  }

  // @todo - Add Description
  /// @return imrValueE30 Total imr of trader's account.
  function getIMR(address _subAccount) external view returns (uint256) {
    return imrOf[_subAccount];
  }

  // @todo - Add Description
  /// @return mmrValueE30 Total mmr of trader's account
  function getMMR(address _subAccount) external view returns (uint256) {
    return mmrOf[_subAccount];
  }

  // =========================================
  // | ---------- Calculator --------------- |
  // =========================================

  function calculatePositionIMR(uint256, uint256) external view returns (uint256) {
    return 0;
  }

  function calculatePositionMMR(uint256, uint256) external view returns (uint256) {
    return 0;
  }

  function getAUM(bool /* isMaxPrice */) external view returns (uint256) {
    return aum;
  }

  function getAUME30(bool /* isMaxPrice */) external view returns (uint256) {
    return aum;
  }

  function getPLPValueE30(bool /* isMaxPrice */) external view returns (uint256) {
    return plpValue;
  }

  function getPLPPrice(uint256 /* aum */, uint256 /* supply */) external pure returns (uint256) {
    // 1$
    return 1e30;
  }

  function getMintAmount(uint256 _aum, uint256 _totalSupply, uint256 _value) external pure returns (uint256) {
    return _aum == 0 ? _value / 1e12 : (_value * _totalSupply) / _aum / 1e12;
  }

  function convertTokenDecimals(
    uint256 _fromTokenDecimals,
    uint256 _toTokenDecimals,
    uint256 _amount
  ) external pure returns (uint256) {
    return (_amount * 10 ** _toTokenDecimals) / 10 ** _fromTokenDecimals;
  }

  function getAddLiquidityFeeRate(
    address /*_token*/,
    uint256 /*_tokenValue*/,
    IConfigStorage /*_configStorage*/,
    IVaultStorage /*_vaultStorage*/
  ) external pure returns (uint256) {
    return 0.003 ether;
  }

  function getRemoveLiquidityFeeRate(
    address /*_token*/,
    uint256 /*_tokenValueE30*/,
    IConfigStorage /*_configStorage*/,
    IVaultStorage /*_vaultStorage*/
  ) external pure returns (uint256) {
    return 1e18;
  }

  function getFreeCollateral(address /*_subAccount*/) external view returns (uint256) {
    return freeCollateral;
  }

  function getNextBorrowingRate(uint256 /*_assetClassIndex*/) external view returns (uint256) {
    return nextBorrowingRate;
  }
}
