// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// lib
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IRebalanceHLPHandler } from "@hmx/handlers/interfaces/IRebalanceHLPHandler.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

/// @title RebalanceHLPHandler
/// @notice This contract handles liquidity orders for adding or removing liquidity from a pool
contract RebalanceHLPHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, IRebalanceHLPHandler {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IRebalanceHLPService public service;
  IVaultStorage public vaultStorage;
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

  function initialize(address _rebalanceHLPService, address _pyth) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    // gas opt
    IRebalanceHLPService _service = IRebalanceHLPService(_rebalanceHLPService);
    service = _service;
    vaultStorage = _service.vaultStorage();
    sglp = _service.sglp();
    pyth = IEcoPyth(_pyth);
  }

  function addGlp(
    IRebalanceHLPService.AddGlpParams[] calldata _params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external onlyWhitelisted returns (uint256 receivedGlp) {
    if (_params.length == 0) revert RebalanceHLPHandler_ParamsIsEmpty();
    // Update the price and publish time data using the Pyth oracle
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // Execute logic at Service
    receivedGlp = service.addGlp(_params);
  }

  function withdrawGlp(
    IRebalanceHLPService.WithdrawGlpParams[] calldata _params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyWhitelisted returns (IRebalanceHLPService.WithdrawGlpResult[] memory result) {
    if (_params.length == 0) revert RebalanceHLPHandler_ParamsIsEmpty();
    // Update the price and publish time data using the Pyth oracle
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // Execute logic at Service
    result = service.withdrawGlp(_params);
  }

  function swap(
    IRebalanceHLPService.SwapParams calldata _params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyWhitelisted returns (uint256 amountOut) {
    // Update the price and publish time data using the Pyth oracle
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // Execute logic at Service
    amountOut = service.swap(_params);
  }

  function oneInchSwap(
    IRebalanceHLPService.SwapParams calldata _params,
    bytes calldata _oneInchData,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyWhitelisted returns (uint256 amountOut) {
    // Update the price and publish time data using the Pyth oracle
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // Execute logic at Service
    amountOut = service.oneInchSwap(_params, _oneInchData);
  }

  function setWhitelistExecutor(address _executor, bool _isAllow) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPHandler_AddressIsZero();
    }
    whitelistExecutors[_executor] = _isAllow;
    emit LogSetWhitelistExecutor(_executor, _isAllow);
  }

  function setRebalanceHLPService(address _newService) external nonReentrant onlyOwner {
    if (_newService == address(0)) {
      revert RebalanceHLPHandler_AddressIsZero();
    }
    emit LogSetRebalanceHLPService(address(service), _newService);
    service = IRebalanceHLPService(_newService);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
