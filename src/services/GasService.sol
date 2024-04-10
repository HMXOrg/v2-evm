// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// bases
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

// contracts
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

// interfaces
import { IGasService } from "@hmx/services/interfaces/IGasService.sol";

contract GasService is ReentrancyGuardUpgradeable, OwnableUpgradeable, IGasService {
  VaultStorage public vaultStorage;
  ConfigStorage public configStorage;
  uint256 public executionFeeInUsd;
  address public executionFeeTreasury;
  uint256 public subsidizedExecutionFeeValue; // The total value of gas fee that is subsidized by the platform in E30
  uint256 public waviedExecutionFeeMinTradeSize; // The minimum trade size (E30) that we will waive exeuction fee

  function initialize(
    address _vaultStorage,
    address _configStorage,
    uint256 _executionFeeInUsd,
    address _executionFeeTreasury
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    vaultStorage = VaultStorage(_vaultStorage);
    configStorage = ConfigStorage(_configStorage);
    executionFeeInUsd = _executionFeeInUsd;
    executionFeeTreasury = _executionFeeTreasury;
  }

  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  /**
   * Functions
   */
  struct VarsCollectExecutionFeeFromCollateral {
    address subAccount;
    address[] traderTokens;
    uint256 len;
    OracleMiddleware oracle;
    uint256 executionFeeToBePaidInUsd;
    bytes32 assetId;
    ConfigStorage.AssetConfig assetConfig;
    address token;
    uint256 userBalance;
    uint256 tokenPrice;
    uint8 tokenDecimal;
    uint256 payAmount;
    uint256 payValue;
  }

  function collectExecutionFeeFromCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _absSizeDelta
  ) external onlyWhitelistedExecutor {
    VarsCollectExecutionFeeFromCollateral memory vars;

    vars.subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    vars.traderTokens = vaultStorage.getTraderTokens(vars.subAccount);
    vars.len = vars.traderTokens.length;
    vars.oracle = OracleMiddleware(configStorage.oracle());

    emit LogCollectExecutionFeeValue(vars.subAccount, _marketIndex, executionFeeInUsd);
    if (_absSizeDelta >= waviedExecutionFeeMinTradeSize) {
      emit LogSubsidizeExecutionFee(vars.subAccount, _marketIndex, executionFeeInUsd);
      subsidizedExecutionFeeValue += executionFeeInUsd;
    } else {
      vars.executionFeeToBePaidInUsd = executionFeeInUsd;
      for (uint256 _i; _i < vars.len; ) {
        vars.assetId = configStorage.tokenAssetIds(vars.traderTokens[_i]);
        vars.assetConfig = configStorage.getAssetConfig(vars.assetId);
        vars.token = vars.assetConfig.tokenAddress;
        vars.userBalance = vaultStorage.traderBalances(vars.subAccount, vars.token);

        if (vars.userBalance > 0) {
          (vars.tokenPrice, ) = vars.oracle.getLatestPrice(vars.assetConfig.assetId, false);
          vars.tokenDecimal = vars.assetConfig.decimals;

          (vars.payAmount, vars.payValue) = _getPayAmount(
            vars.userBalance,
            vars.executionFeeToBePaidInUsd,
            vars.tokenPrice,
            vars.tokenDecimal
          );
          emit LogCollectExecutionFeeAmount(vars.subAccount, _marketIndex, vars.token, vars.payAmount);

          vaultStorage.decreaseTraderBalance(vars.subAccount, vars.token, vars.payAmount);
          vaultStorage.increaseTraderBalance(executionFeeTreasury, vars.token, vars.payAmount);

          vars.executionFeeToBePaidInUsd -= vars.payValue;

          if (vars.executionFeeToBePaidInUsd == 0) {
            break;
          }
        }

        unchecked {
          ++_i;
        }
      }

      if (vars.executionFeeToBePaidInUsd > 0) {
        vaultStorage.addTradingFeeDebt(vars.subAccount, vars.executionFeeToBePaidInUsd);
      }
    }
  }

  function adjustSubsidizedExecutionFeeValue(int256 deltaValueE30) external onlyWhitelistedExecutor {
    uint256 previousValue = subsidizedExecutionFeeValue;
    if (deltaValueE30 >= 0) {
      subsidizedExecutionFeeValue += uint256(deltaValueE30);
    } else {
      subsidizedExecutionFeeValue -= uint256(-deltaValueE30);
    }
    emit LogAdjustSubsidizedExecutionFeeValue(previousValue, subsidizedExecutionFeeValue, deltaValueE30);
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

  function setParams(uint256 _executionFeeInUsd, address _executionFeeTreasury) external onlyOwner {
    executionFeeInUsd = _executionFeeInUsd;
    executionFeeTreasury = _executionFeeTreasury;

    emit LogSetParams(_executionFeeInUsd, _executionFeeTreasury);
  }

  function setWaviedExecutionFeeMinTradeSize(uint256 _waviedExecutionFeeMinTradeSize) external onlyOwner {
    waviedExecutionFeeMinTradeSize = _waviedExecutionFeeMinTradeSize;

    emit LogSetWaviedExecutionFeeMinTradeSize(waviedExecutionFeeMinTradeSize);
  }
}
