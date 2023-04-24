// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Vm } from "forge-std/Vm.sol";

// Interfaces
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";

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

import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";
import { ITraderLoyaltyCredit } from "@hmx/tokens/interfaces/ITraderLoyaltyCredit.sol";
import { ITLCStaking } from "@hmx/staking/interfaces/ITLCStaking.sol";
import { IEpochRewarder } from "@hmx/staking/interfaces/IEpochRewarder.sol";
import { IVester } from "@hmx/vesting/interfaces/IVester.sol";

import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";

import { StakedGlpStrategy } from "@hmx/strategies/StakedGlpStrategy.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";

library Deployer {
  Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  /**
   * General Contracts
   */

  function deployPLPv2() internal returns (IPLPv2) {
    return IPLPv2(deployContract("PLPv2"));
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

  function deployStakedGlpOracleAdapter(
    IERC20 _sGlp,
    IGmxGlpManager _glpManager,
    bytes32 _sGlpAssetId
  ) internal returns (IOracleAdapter) {
    return
      IOracleAdapter(
        deployContractWithArguments("StakedGlpOracleAdapter", abi.encode(_sGlp, _glpManager, _sGlpAssetId))
      );
  }

  function deployOracleMiddleware() internal returns (IOracleMiddleware) {
    return IOracleMiddleware(deployContract("OracleMiddleware"));
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

  function deployCrossMarginHandler(
    address _crossMarginService,
    address _pyth,
    uint256 _minExecutionFee
  ) internal returns (ICrossMarginHandler) {
    return
      ICrossMarginHandler(
        deployContractWithArguments("CrossMarginHandler", abi.encode(_crossMarginService, _pyth, _minExecutionFee))
      );
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
    address _perpStorage,
    address _calculator
  ) internal returns (ICrossMarginService) {
    return
      ICrossMarginService(
        deployContractWithArguments(
          "CrossMarginService",
          abi.encode(_configStorage, _vaultStorage, _perpStorage, _calculator)
        )
      );
  }

  function deployTradeService(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _tradeHelper
  ) internal returns (ITradeService) {
    return
      ITradeService(
        deployContractWithArguments(
          "TradeService",
          abi.encode(_perpStorage, _vaultStorage, _configStorage, _tradeHelper)
        )
      );
  }

  function deployLiquidationService(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _tradeHelper
  ) internal returns (ILiquidationService) {
    return
      ILiquidationService(
        deployContractWithArguments(
          "LiquidationService",
          abi.encode(_perpStorage, _vaultStorage, _configStorage, _tradeHelper)
        )
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

  function deployTradeHelper(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage
  ) internal returns (ITradeHelper) {
    return
      ITradeHelper(deployContractWithArguments("TradeHelper", abi.encode(_perpStorage, _vaultStorage, _configStorage)));
  }

  function deployTLCToken() internal returns (ITraderLoyaltyCredit) {
    return ITraderLoyaltyCredit(deployContract("TraderLoyaltyCredit"));
  }

  function deployTLCHook(
    address _tradeService,
    address _tlc,
    address _tlcStaking
  ) internal returns (ITradeServiceHook) {
    return ITradeServiceHook(deployContractWithArguments("TLCHook", abi.encode(_tradeService, _tlc, _tlcStaking)));
  }

  function deployTLCStaking(address _proxyAdmin, address _stakingToken) internal returns (ITLCStaking) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TLCStaking.sol/TLCStaking.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize(address)")), _stakingToken);
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITLCStaking(payable(_proxy));
  }

  function deployEpochFeedableRewarder(
    address _proxyAdmin,
    string memory _name,
    address _rewardToken,
    address _staking
  ) internal returns (IEpochRewarder) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/EpochFeedableRewarder.sol/EpochFeedableRewarder.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(string,address,address)")),
      _name,
      _rewardToken,
      _staking
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IEpochRewarder(payable(_proxy));
  }

  function deployVester(
    address _proxyAdmin,
    address esHMXAddress,
    address hmxAddress,
    address vestedEsHmxDestinationAddress,
    address unusedEsHmxDestinationAddress
  ) internal returns (IVester) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/Vester.sol/Vester.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      esHMXAddress,
      hmxAddress,
      vestedEsHmxDestinationAddress,
      unusedEsHmxDestinationAddress
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IVester(payable(_proxy));
  }

  function deployStakedGlpStrategy(
    IERC20 _sGlp,
    IGmxRewardRouterV2 _rewardRouter,
    IGmxRewardTracker _rewardTracker,
    IGmxGlpManager _glpManager,
    IOracleMiddleware _oracleMiddleware,
    IVaultStorage _vaultStorage,
    address _keeper,
    address _treasury,
    uint16 _strategyBps
  ) internal returns (IStrategy) {
    return
      IStrategy(
        deployContractWithArguments(
          "StakedGlpStrategy",
          abi.encode(
            _sGlp,
            _rewardRouter,
            _rewardTracker,
            _glpManager,
            _oracleMiddleware,
            _vaultStorage,
            _keeper,
            _treasury,
            _strategyBps
          )
        )
      );
  }

  /**
   * Private Functions
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

  function _setupUpgradeable(
    bytes memory _logicBytecode,
    bytes memory _initializer,
    address _proxyAdmin
  ) internal returns (address) {
    bytes memory _proxyBytecode = abi.encodePacked(
      vm.getCode("./out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json")
    );

    address _logic;
    assembly {
      _logic := create(0, add(_logicBytecode, 0x20), mload(_logicBytecode))
    }

    _proxyBytecode = abi.encodePacked(_proxyBytecode, abi.encode(_logic, _proxyAdmin, _initializer));

    address _proxy;
    assembly {
      _proxy := create(0, add(_proxyBytecode, 0x20), mload(_proxyBytecode))
      if iszero(extcodesize(_proxy)) {
        revert(0, 0)
      }
    }

    return _proxy;
  }
}
