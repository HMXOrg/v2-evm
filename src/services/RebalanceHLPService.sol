// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// interfaces
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ISwitchCollateralRouter } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralRouter.sol";

contract RebalanceHLPService is OwnableUpgradeable, IRebalanceHLPService {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  ICalculator public calculator;

  ISwitchCollateralRouter public switchRouter;

  uint16 public minHLPValueLossBPS;

  // 2023-11-08: Add 1inch router to support 1inch swap
  address public oneInchRouter;

  modifier onlyWhitelisted() {
    configStorage.validateServiceExecutor(address(this), msg.sender);
    _;
  }

  event LogSetOneInchRouter(address oldValue, address newValue);
  event LogSetMinHLPValueLossBPS(uint16 oldValue, uint16 newValue);

  function initialize(
    address _vaultStorage,
    address _configStorage,
    address _calculator,
    address _switchCollateralRouter,
    uint16 _minHLPValueLossBPS
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
    calculator = ICalculator(_calculator);
    switchRouter = ISwitchCollateralRouter(_switchCollateralRouter);
    minHLPValueLossBPS = _minHLPValueLossBPS;
  }

  function swap(SwapParams calldata _params) external onlyWhitelisted returns (uint256 _amountOut) {
    // Checks
    // Check if path is valid
    if (_params.path.length < 2) revert RebalanceHLPService_InvalidPath();
    // Cast dependencies to local variables to save on SLOADs.
    IVaultStorage _vaultStorage = vaultStorage;
    IConfigStorage _configStorage = configStorage;
    // Check if swap HLP liquidity from one to another is valid
    _configStorage.validateAcceptedCollateral(_params.path[0]);
    _configStorage.validateAcceptedCollateral(_params.path[_params.path.length - 1]);
    // Check if amountIn is valid.
    if (_params.amountIn == 0) revert RebalanceHLPService_AmountIsZero();
    // Cache TVL here to check if HLP value drop too much after swap
    uint256 tvlBefore = calculator.getHLPValueE30(true);

    // Preps
    (address _tokenIn, address _tokenOut) = (_params.path[0], _params.path[_params.path.length - 1]);

    // Remove HLP liquidity from tokenIn and push to switchRouter.
    _vaultStorage.removeHLPLiquidity(_tokenIn, _params.amountIn);
    _vaultStorage.pushToken(_tokenIn, address(switchRouter), _params.amountIn);

    // Run switchRouter, it will send back _tokenOut to this contract
    _amountOut = switchRouter.execute(uint256(_params.amountIn), _params.path);
    // Check slippage
    if (_amountOut < _params.minAmountOut) revert RebalanceHLPService_Slippage();

    // Send last token to VaultStorage and pull
    IERC20Upgradeable(_tokenOut).safeTransfer(address(_vaultStorage), _amountOut);
    uint256 _deltaBalance = _vaultStorage.pullToken(_tokenOut);
    if (_deltaBalance < _amountOut) revert RebalanceHLPService_InvalidTokenAmount();
    // Increase HLP's liquidity
    _vaultStorage.addHLPLiquidity(_tokenOut, _amountOut);

    // Check if HLP value drop too much after swap before return
    _validateHLPValue(tvlBefore);
  }

  function oneInchSwap(
    SwapParams calldata _params,
    bytes calldata _oneInchCalldata
  ) external onlyWhitelisted returns (uint256 _amountOut) {
    // Checks
    // Check if path is valid
    if (_params.path.length < 2) revert RebalanceHLPService_InvalidPath();
    // Cast dependencies to local variables to save on SLOADs.
    IVaultStorage _vaultStorage = vaultStorage;
    IConfigStorage _configStorage = configStorage;
    // Check if swap HLP liquidity from one to another is valid
    _configStorage.validateAcceptedCollateral(_params.path[0]);
    _configStorage.validateAcceptedCollateral(_params.path[_params.path.length - 1]);
    // Check if amountIn is valid.
    if (_params.amountIn == 0) revert RebalanceHLPService_AmountIsZero();
    // Cache TVL here to check if HLP value drop too much after swap
    uint256 tvlBefore = calculator.getHLPValueE30(true);

    // Preps
    (address _tokenIn, address _tokenOut) = (_params.path[0], _params.path[_params.path.length - 1]);

    // Remove HLP liquidity from tokenIn and push to address(this).
    _vaultStorage.removeHLPLiquidity(_tokenIn, _params.amountIn);
    _vaultStorage.pushToken(_tokenIn, address(this), _params.amountIn);

    // Approve 1inch router to spend tokenIn
    IERC20Upgradeable(_tokenIn).safeIncreaseAllowance(oneInchRouter, _params.amountIn);

    // Call 1inch swap.
    (bool _success, ) = oneInchRouter.call(_oneInchCalldata);
    if (!_success) revert RebalanceHLPService_OneInchSwapFailed();

    // Check slippage
    _amountOut = IERC20Upgradeable(_tokenOut).balanceOf(address(this));
    if (_amountOut < _params.minAmountOut) revert RebalanceHLPService_Slippage();

    // Send _tokenOut to VaultStorage and pull
    IERC20Upgradeable(_tokenOut).safeTransfer(address(_vaultStorage), _amountOut);
    uint256 _deltaBalance = _vaultStorage.pullToken(_tokenOut);
    if (_deltaBalance < _amountOut) revert RebalanceHLPService_InvalidTokenAmount();
    // Increase HLP's liquidity
    _vaultStorage.addHLPLiquidity(_tokenOut, _amountOut);

    // Check if HLP value drop too much after swap before return
    _validateHLPValue(tvlBefore);
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
        revert RebalanceHLPService_HlpTvlDropExceedMin();
      }
    }
  }

  function setMinHLPValueLossBPS(uint16 _HLPValueLossBPS) external onlyOwner {
    if (_HLPValueLossBPS == 0) {
      revert RebalanceHLPService_AmountIsZero();
    }
    emit LogSetMinHLPValueLossBPS(minHLPValueLossBPS, _HLPValueLossBPS);
    minHLPValueLossBPS = _HLPValueLossBPS;
  }

  function setOneInchRouter(address _oneInchRouter) external onlyOwner {
    emit LogSetOneInchRouter(oneInchRouter, _oneInchRouter);
    oneInchRouter = _oneInchRouter;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
