// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IRebalanceHLPHandler } from "@hmx/handlers/interfaces/IRebalanceHLPHandler.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

/// @title RebalanceHLPHandler
/// @notice This contract handles liquidity orders for adding or removing liquidity from a pool
contract RebalanceHLPHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, IRebalanceHLPHandler {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IRebalanceHLPService public service;
  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  ICalculator public calculator;
  IEcoPyth public pyth;
  IERC20Upgradeable public sglp;

  uint16 public minHLPValueLossBPS;

  mapping(address => bool) public whitelistExecutors;

  event LogSetMinHLPValueLossBPS(uint16 _oldFee, uint16 _newFee);
  event LogSetRebalanceHLPService(address indexed _oldService, address indexed _newService);
  event LogSetWhitelistExecutor(address indexed _executor, bool _isAllow);

  modifier onlyWhitelisted() {
    if (!whitelistExecutors[msg.sender]) revert IRebalanceHLPHandler.RebalanceHLPHandler_NotWhiteListed();
    _;
  }

  function initialize(
    address _rebalanceHLPService,
    address _calculator,
    address _configStorage,
    address _pyth,
    uint16 _minHLPValueLossBPS
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    // gas opt
    IRebalanceHLPService _service = IRebalanceHLPService(_rebalanceHLPService);
    service = _service;
    vaultStorage = _service.vaultStorage();
    sglp = _service.sglp();
    calculator = ICalculator(_calculator);
    configStorage = IConfigStorage(_configStorage);
    pyth = IEcoPyth(_pyth);
    minHLPValueLossBPS = _minHLPValueLossBPS;
  }

  function setWhiteListExecutor(address _executor, bool _isAllow) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPHandler_AddressIsZero();
    }
    whitelistExecutors[_executor] = _isAllow;
    emit LogSetWhitelistExecutor(_executor, _isAllow);
  }

  function setMinHLPValueLossBPS(uint16 _HLPValueLossBPS) external onlyOwner {
    if (_HLPValueLossBPS == 0) {
      revert RebalanceHLPHandler_AmountIsZero();
    }
    emit LogSetMinHLPValueLossBPS(minHLPValueLossBPS, _HLPValueLossBPS);
    minHLPValueLossBPS = _HLPValueLossBPS;
  }

  function setRebalanceHLPService(address _newService) external nonReentrant onlyOwner {
    if (_newService == address(0)) {
      revert RebalanceHLPHandler_AddressIsZero();
    }
    emit LogSetRebalanceHLPService(address(service), _newService);
    service = IRebalanceHLPService(_newService);
  }

  function executeLogicReinvestNonHLP(
    IRebalanceHLPService.ExecuteReinvestParams[] calldata _params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external onlyWhitelisted returns (uint256 receivedGlp) {
    if (_params.length == 0) revert RebalanceHLPHandler_ParamsIsEmpty();
    _validateReinvestInput(_params);
    // Update the price and publish time data using the Pyth oracle
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // Get current HLP value
    uint256 totalHlpValueBefore = calculator.getHLPValueE30(true);
    // Execute logic at Service
    receivedGlp = service.executReinvestNonHLP(_params);
    // Validate HLP Value
    _validateHLPValue(totalHlpValueBefore);
  }

  function executeLogicWithdrawGLP(
    IRebalanceHLPService.ExecuteWithdrawParams[] calldata _params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyWhitelisted returns (IRebalanceHLPService.WithdrawGLPResult[] memory result) {
    if (_params.length == 0) revert RebalanceHLPHandler_ParamsIsEmpty();
    _validateWithdrawInput(_params);
    // Update the price and publish time data using the Pyth oracle
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // Get current HLP value
    uint256 totalHlpValueBefore = calculator.getHLPValueE30(true);
    // Execute logic at Service
    result = service.executeWithdrawGLP(_params);
    // Validate HLP Value
    _validateHLPValue(totalHlpValueBefore);
  }

  function _validateReinvestInput(IRebalanceHLPService.ExecuteReinvestParams[] calldata _params) internal {
    // SLOAD
    IVaultStorage _vaultStorage = vaultStorage;
    for (uint256 i = 0; i < _params.length; ) {
      if (_params[i].token == address(0)) {
        revert RebalanceHLPHandler_InvalidTokenAddress();
      }
      if ((_params[i].amount > _vaultStorage.totalAmount(_params[i].token)) || (_params[i].amount == 0)) {
        revert RebalanceHLPHandler_InvalidTokenAmount();
      }
      unchecked {
        ++i;
      }
    }
  }

  function _validateWithdrawInput(IRebalanceHLPService.ExecuteWithdrawParams[] calldata _params) internal {
    // SLOAD
    IVaultStorage _vaultStorage = vaultStorage;
    uint256 totalGlpAccum = 0;
    for (uint256 i = 0; i < _params.length; ) {
      if (_params[i].token == address(0)) {
        revert RebalanceHLPHandler_InvalidTokenAddress();
      }
      totalGlpAccum += _params[i].glpAmount;
      unchecked {
        ++i;
      }
    }
    if (_vaultStorage.totalAmount(address(sglp)) < totalGlpAccum) {
      revert RebalanceHLPHandler_InvalidTokenAmount();
    }
  }

  function _validateHLPValue(uint256 _valueBefore) internal view {
    uint256 hlpValue = calculator.getHLPValueE30(true);
    if (_valueBefore > hlpValue) {
      uint256 diff = _valueBefore - hlpValue;
      /**
      EQ:  ( Before - After )          minHLPValueLossBPS
            ----------------     >      ----------------
                Before                        BPS
      
      To reduce the div,   ( Before - After ) * (BPS**2) = minHLPValueLossBPS * Before
       */
      if ((diff * 1e4) > (minHLPValueLossBPS * _valueBefore)) {
        revert RebalanceHLPHandler_HlpTvlDropExceedMin();
      }
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
