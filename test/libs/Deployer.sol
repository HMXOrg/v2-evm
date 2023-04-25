// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Vm } from "forge-std/Vm.sol";

// Interfaces
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

import { IPyth } from "@hmx/oracles/interfaces/IPyth.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { ILeanPyth } from "@hmx/oracles/interfaces/ILeanPyth.sol";
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
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

library Deployer {
  Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  /**
   * General Contracts
   */

  function deployPLPv2(address _proxyAdmin) internal returns (IPLPv2) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/PLPv2.sol/PLPv2.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IPLPv2(payable(_proxy));
  }

  function deployCalculator(
    address _proxyAdmin,
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) internal returns (ICalculator) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/Calculator.sol/Calculator.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      _oracle,
      _vaultStorage,
      _perpStorage,
      _configStorage
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ICalculator(payable(_proxy));
  }

  /**
   * Oracles
   */

  function deployPythAdapter(address _proxyAdmin, address _pyth) internal returns (IPythAdapter) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/PythAdapter.sol/PythAdapter.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize(address)")), _pyth);
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IPythAdapter(payable(_proxy));
  }

  function deployStakedGlpOracleAdapter(
    address _proxyAdmin,
    IERC20Upgradeable _sGlp,
    IGmxGlpManager _glpManager,
    bytes32 _sGlpAssetId
  ) internal returns (IOracleAdapter) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/StakedGlpOracleAdapter.sol/StakedGlpOracleAdapter.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,IERC20Upgradeable,IGmxGlpManager,bytes32)")),
      _sGlp,
      _glpManager,
      _sGlpAssetId
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IOracleAdapter(payable(_proxy));
  }

  function deployOracleMiddleware(address _proxyAdmin) internal returns (IOracleMiddleware) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/OracleMiddleware.sol/OracleMiddleware.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IOracleMiddleware(payable(_proxy));
  }

  function deployLeanPyth(address _proxyAdmin, IPyth _pyth) internal returns (ILeanPyth) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/LeanPyth.sol/LeanPyth.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize(IPyth)")), _pyth);
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ILeanPyth(payable(_proxy));
  }

  /**
   * Storages
   */

  function deployConfigStorage(address _proxyAdmin) internal returns (IConfigStorage) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/ConfigStorage.sol/ConfigStorage.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IConfigStorage(payable(_proxy));
  }

  function deployPerpStorage(address _proxyAdmin) internal returns (IPerpStorage) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/PerpStorage.sol/PerpStorage.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IPerpStorage(payable(_proxy));
  }

  function deployVaultStorage(address _proxyAdmin) internal returns (IVaultStorage) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/VaultStorage.sol/VaultStorage.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IVaultStorage(payable(_proxy));
  }

  /**
   * Handlers
   */

  function deployCrossMarginHandler(
    address _proxyAdmin,
    address _crossMarginService,
    address _pyth,
    uint256 _executionOrderFee
  ) internal returns (ICrossMarginHandler) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/CrossMarginHandler.sol/CrossMarginHandler.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,uint256)")),
      _crossMarginService,
      _pyth,
      _executionOrderFee
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ICrossMarginHandler(payable(_proxy));
  }

  function deployLiquidityHandler(
    address _proxyAdmin,
    address _liquidityService,
    address _pyth,
    uint256 _executionOrderFee
  ) internal returns (ILiquidityHandler) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/LiquidityHandler.sol/LiquidityHandler.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,uint256)")),
      _liquidityService,
      _pyth,
      _executionOrderFee
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ILiquidityHandler(payable(_proxy));
  }

  function deployLimitTradeHandler(
    address _proxyAdmin,
    address _weth,
    address _tradeService,
    address _pyth,
    uint256 _minExecutionFee
  ) internal returns (ILimitTradeHandler) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/LimitTradeHandler.sol/LimitTradeHandler.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,uint256)")),
      _weth,
      _tradeService,
      _pyth,
      _minExecutionFee
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ILimitTradeHandler(payable(_proxy));
  }

  function deployMarketTradeHandler(
    address _proxyAdmin,
    address _tradeService,
    address _pyth
  ) internal returns (IMarketTradeHandler) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/MarketTradeHandler.sol/MarketTradeHandler.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address)")),
      _tradeService,
      _pyth
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IMarketTradeHandler(payable(_proxy));
  }

  function deployBotHandler(
    address _proxyAdmin,
    address _tradeService,
    address _liquidationService,
    address _pyth
  ) internal returns (IBotHandler) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/BotHandler.sol/BotHandler.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address)")),
      _tradeService,
      _liquidationService,
      _pyth
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IBotHandler(payable(_proxy));
  }

  /**
   * Staking
   */

  function deployTradingStaking(address _proxyAdmin) internal returns (ITradingStaking) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TradingStaking.sol/TradingStaking.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize())")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITradingStaking(payable(_proxy));
  }

  function deployTradingStakingHook(
    address _proxyAdmin,
    address _tradingStaking,
    address _tradeService
  ) internal returns (ITradeServiceHook) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TradingStakingHook.sol/TradingStakingHook.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address)")),
      _tradingStaking,
      _tradeService
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITradeServiceHook(payable(_proxy));
  }

  function deployFeedableRewarder(
    address _proxyAdmin,
    string memory _name,
    address _rewardToken,
    address _staking
  ) internal returns (IRewarder) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/FeedableRewarder.sol/FeedableRewarder.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(string,address,address)")),
      _name,
      _rewardToken,
      _staking
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IRewarder(payable(_proxy));
  }

  function deployTLCStaking(address _proxyAdmin, address _stakingToken) internal returns (ITLCStaking) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TLCStaking.sol/TLCStaking.json"));
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize(address)")), _stakingToken);
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITLCStaking(payable(_proxy));
  }

  function deployTLCHook(
    address _proxyAdmin,
    address _tradeService,
    address _tlc,
    address _tlcStaking
  ) internal returns (ITradeServiceHook) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TLCHook.sol/TLCHook.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address)")),
      _tradeService,
      _tlc,
      _tlcStaking
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITradeServiceHook(payable(_proxy));
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

  /**
   * Services
   */

  function deployCrossMarginService(
    address _proxyAdmin,
    address _configStorage,
    address _vaultStorage,
    address _perpStorage,
    address _calculator
  ) internal returns (ICrossMarginService) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/CrossMarginService.sol/CrossMarginService.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      _configStorage,
      _vaultStorage,
      _perpStorage,
      _calculator
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ICrossMarginService(payable(_proxy));
  }

  function deployTradeService(
    address _proxyAdmin,
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _tradeHelper
  ) internal returns (ITradeService) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TradeService.sol/TradeService.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      _perpStorage,
      _vaultStorage,
      _configStorage,
      _tradeHelper
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITradeService(payable(_proxy));
  }

  function deployLiquidationService(
    address _proxyAdmin,
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _tradeHelper
  ) internal returns (ILiquidationService) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/LiquidationService.sol/LiquidationService.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      _perpStorage,
      _vaultStorage,
      _configStorage,
      _tradeHelper
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ILiquidationService(payable(_proxy));
  }

  function deployLiquidityService(
    address _proxyAdmin,
    address _perpStorage,
    address _vaultStorage,
    address _configStorage
  ) internal returns (ILiquidityService) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/LiquidityService.sol/LiquidityService.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      _perpStorage,
      _vaultStorage,
      _configStorage
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ILiquidityService(payable(_proxy));
  }

  /**
   * Helpers
   */

  function deployTradeHelper(
    address _proxyAdmin,
    address _perpStorage,
    address _vaultStorage,
    address _configStorage
  ) internal returns (ITradeHelper) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/TradeHelper.sol/TradeHelper.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      _perpStorage,
      _vaultStorage,
      _configStorage
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITradeHelper(payable(_proxy));
  }

  /**
   * Tokens
   */

  function deployTLCToken(address _proxyAdmin) internal returns (ITraderLoyaltyCredit) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/TraderLoyaltyCredit.sol/TraderLoyaltyCredit.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return ITraderLoyaltyCredit(payable(_proxy));
  }

  /*
   * Vesting
   */

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

  /*
   * Strategies
   */

  function deployStakedGlpStrategy(
    address _proxyAdmin,
    IERC20Upgradeable _sGlp,
    IStrategy.StakedGlpStrategyConfig memory _stakedGlpStrategyConfig,
    address _keeper,
    address _treasury,
    uint16 _strategyBps
  ) internal returns (IStrategy) {
    bytes memory _logicBytecode = abi.encodePacked(vm.getCode("./out/StakedGlpStrategy.sol/StakedGlpStrategy.json"));
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(IERC20Upgradeable,IStrategy.StakedGlpStrategyConfig,address,address,uint16)")),
      _sGlp,
      _stakedGlpStrategyConfig,
      _keeper,
      _treasury,
      _strategyBps
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer, _proxyAdmin);
    return IStrategy(payable(_proxy));
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
