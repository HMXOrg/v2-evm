// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

// contracts
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";

// interfaces

/// @title IntentHandler
contract IntentHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  ConfigStorage public configStorage;
  VaultStorage public vaultStorage;
  uint256 public executionFeeInUsd;
  address public executionFeeTreasury;

  error IntentHandler_NotEnoughCollateral();

  function collectExecutionFeeFromCollateral(address _primaryAccount, uint8 _subAccountId) internal {
    bytes32[] memory _hlpAssetIds = configStorage.getHlpAssetIds();
    uint256 _len = _hlpAssetIds.length;
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    OracleMiddleware _oracle = OracleMiddleware(configStorage.oracle());

    uint256 _executionFeeToBePaidInUsd = executionFeeInUsd;
    for (uint256 _i; _i < _len; ) {
      ConfigStorage.AssetConfig memory _assetConfig = configStorage.getAssetConfig(_hlpAssetIds[_i]);
      uint256 _userBalance = vaultStorage.traderBalances(_subAccount, _token);

      if (_userBalance > 0) {
        (uint256 _tokenPrice, ) = _oracle.getLatestPrice(_assetConfig.assetId, false);
        uint8 _tokenDecimal = _assetConfig.decimals;
        address _token = _assetConfig.tokenAddress;

        (uint256 _payAmount, uint256 _payValue) = _getPayAmount(
          _userBalance,
          _executionFeeToBePaidInUsd,
          _tokenPrice,
          _tokenDecimal
        );

        vaultStorage.decreaseTraderBalance(_subAccount, _token, _payAmount);
        vaultStorage.increaseTraderBalance(executionFeeTreasury, _token, _payAmount);

        _executionFeeToBePaidInUsd -= _payValue;

        if (_executionFeeToBePaidInUsd == 0) {
          break;
        }
      }

      unchecked {
        ++_i;
      }
    }

    if (_executionFeeToBePaidInUsd > 0) {
      revert IntentHandler_NotEnoughCollateral();
    }
  }

  function _getPayAmount(
    uint256 _payerBalance,
    uint256 _valueE30,
    uint256 _tokenPrice,
    uint8 _tokenDecimal
  ) internal pure returns (uint256 _payAmount, uint256 _payValueE30) {
    uint256 _feeAmount = (_valueE30 * (10 ** _tokenDecimal)) / _tokenPrice;

    if (_payerBalance > _feeAmount) {
      // _payerBalance can cover the rest of the fee
      return (_feeAmount, _valueE30);
    } else {
      // _payerBalance cannot cover the rest of the fee, just take the amount the trader have
      uint256 _payerBalanceValue = (_payerBalance * _tokenPrice) / (10 ** _tokenDecimal);
      return (_payerBalance, _payerBalanceValue);
    }
  }
}
