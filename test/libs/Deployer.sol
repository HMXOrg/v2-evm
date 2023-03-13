// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Vm } from "forge-std/Vm.sol";

// Interfaces
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IFeeCalculator } from "@hmx/contracts/interfaces/IFeeCalculator.sol";

import { IPythAdapter } from "@hmx/oracle/interfaces/IPythAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";
import { IMarketTradeHandler } from "@hmx/handlers/interfaces/IMarketTradeHandler.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ILiquidationService } from "@hmx/services/interfaces/ILiquidationService.sol";
import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";

library Deployer {
  Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  /**
   * General Contracts
   */

  function deployPLPv2() internal returns (IPLPv2) {
    return IPLPv2(deployContract("PLPv2"));
  }

  function deployFeeCalculator(address _vaultStorage, address _configStorage) internal returns (IFeeCalculator) {
    bytes memory _args = abi.encode(_vaultStorage, _configStorage);
    return IFeeCalculator(deployContractWithArguments("FeeCalculator", _args));
  }

  function deployCalculator(
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) internal returns (ICalculator) {
    bytes memory _args = abi.encode(_oracle, _vaultStorage, _perpStorage, _configStorage);
    return ICalculator(deployContractWithArguments("Calculator", _args));
  }

  /**
   * Oracles
   */

  function deployPythAdapter(address _pyth) internal returns (IPythAdapter) {
    return IPythAdapter(deployContractWithArguments("PythAdapter", abi.encode(_pyth)));
  }

  function deployOracleMiddleware(address _pythAdapter) internal returns (IOracleMiddleware) {
    return IOracleMiddleware(deployContractWithArguments("OracleMiddleware", abi.encode(_pythAdapter)));
  }

  /**
   * Storages
   */

  function deployConfigStorage() internal returns (IConfigStorage) {
    return IConfigStorage(deployContract("ConfigStorage"));
  }

  function deployPerpStorage() internal returns (IPerpStorage) {
    return IPerpStorage(deployContract("PerpStorage"));
  }

  function deployVaultStorage() internal returns (IVaultStorage) {
    return IVaultStorage(deployContract("VaultStorage"));
  }

  /**
   * Handlers
   */

  function deployCrossMarginHandler(address _crossMarginService, address _pyth) internal returns (ICrossMarginHandler) {
    return
      ICrossMarginHandler(deployContractWithArguments("CrossMarginHandler", abi.encode(_crossMarginService, _pyth)));
  }

  function deployLiquidityHandler(
    address _liquidityService,
    address _pyth,
    uint256 _minExecutionFee
  ) internal returns (ILiquidityHandler) {
    return
      ILiquidityHandler(
        deployContractWithArguments("LiquidityHandler", abi.encode(_liquidityService, _pyth, _minExecutionFee))
      );
  }

  function deployLimitTradeHandler(
    address _weth,
    address _tradeService,
    address _pyth,
    uint256 _minExecutionFee
  ) internal returns (ILimitTradeHandler) {
    return
      ILimitTradeHandler(
        deployContractWithArguments("LimitTradeHandler", abi.encode(_weth, _tradeService, _pyth, _minExecutionFee))
      );
  }

  function deployMarketTradeHandler(address _tradeService, address _pyth) internal returns (IMarketTradeHandler) {
    return IMarketTradeHandler(deployContractWithArguments("MarketTradeHandler", abi.encode(_tradeService, _pyth)));
  }

  function deployBotHandler(
    address _tradeService,
    address _liquidationService,
    address _pyth
  ) internal returns (IBotHandler) {
    return
      IBotHandler(deployContractWithArguments("BotHandler", abi.encode(_tradeService, _liquidationService, _pyth)));
  }

  function deployTradingStaking() internal returns (ITradingStaking) {
    return ITradingStaking(deployContract("TradingStaking"));
  }

  function deployTradingStakingHook(
    address _tradingStaking,
    address _tradeService
  ) internal returns (ITradeServiceHook) {
    return
      ITradeServiceHook(deployContractWithArguments("TradingStakingHook", abi.encode(_tradingStaking, _tradeService)));
  }

  function deployFeedableRewarder(
    string memory name_,
    address rewardToken_,
    address staking_
  ) internal returns (IRewarder) {
    return IRewarder(deployContractWithArguments("FeedableRewarder", abi.encode(name_, rewardToken_, staking_)));
  }

  /**
   * Services
   */

  function deployCrossMarginService(
    address _configStorage,
    address _vaultStorage,
    address _calculator
  ) internal returns (ICrossMarginService) {
    return
      ICrossMarginService(
        deployContractWithArguments("CrossMarginService", abi.encode(_configStorage, _vaultStorage, _calculator))
      );
  }

  function deployTradeService(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage
  ) internal returns (ITradeService) {
    return
      ITradeService(
        deployContractWithArguments("TradeService", abi.encode(_perpStorage, _vaultStorage, _configStorage))
      );
  }

  function deployLiquidationService(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage
  ) internal returns (ILiquidationService) {
    return
      ILiquidationService(
        deployContractWithArguments("LiquidationService", abi.encode(_perpStorage, _vaultStorage, _configStorage))
      );
  }

  function deployLiquidityService(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage
  ) internal returns (ILiquidityService) {
    return
      ILiquidityService(
        deployContractWithArguments("LiquidityService", abi.encode(_perpStorage, _vaultStorage, _configStorage))
      );
  }

  /**
   * Private function
   */

  function deployContract(string memory _name) internal returns (address _deployedAddress) {
    string memory _jsonFile = string.concat("./out/", _name, ".sol/", _name, ".json");

    bytes memory _logicBytecode = abi.encodePacked(vm.getCode(_jsonFile));

    assembly {
      _deployedAddress := create(0, add(_logicBytecode, 0x20), mload(_logicBytecode))
      if iszero(extcodesize(_deployedAddress)) {
        revert(0, 0)
      }
    }
  }

  function deployContractWithArguments(
    string memory _name,
    bytes memory _args
  ) internal returns (address _deployedAddress) {
    string memory _jsonFile = string.concat("./out/", _name, ".sol/", _name, ".json");

    bytes memory _logicBytecode = abi.encodePacked(vm.getCode(_jsonFile), _args);

    assembly {
      _deployedAddress := create(0, add(_logicBytecode, 0x20), mload(_logicBytecode))
      if iszero(extcodesize(_deployedAddress)) {
        revert(0, 0)
      }
    }
  }
}
