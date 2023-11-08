// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// interfaces
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ISwitchCollateralRouter } from "@hmx/extensions/switch-collateral/interfaces/ISwitchCollateralRouter.sol";

contract RebalanceHLPService is OwnableUpgradeable, IRebalanceHLPService {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable public sglp;
  IGmxRewardRouterV2 public rewardRouter;
  IGmxGlpManager public glpManager;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  ICalculator public calculator;

  ISwitchCollateralRouter public switchRouter;

  uint16 public minHLPValueLossBPS;

  modifier onlyWhitelisted() {
    configStorage.validateServiceExecutor(address(this), msg.sender);
    _;
  }

  event LogSetMinHLPValueLossBPS(uint16 oldValue, uint16 newValue);

  function initialize(
    address _sglp,
    address _rewardRouter,
    address _glpManager,
    address _vaultStorage,
    address _configStorage,
    address _calculator,
    address _switchCollateralRouter,
    uint16 _minHLPValueLossBPS
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    sglp = IERC20Upgradeable(_sglp);
    rewardRouter = IGmxRewardRouterV2(_rewardRouter);
    glpManager = IGmxGlpManager(_glpManager);
    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
    calculator = ICalculator(_calculator);
    switchRouter = ISwitchCollateralRouter(_switchCollateralRouter);
    minHLPValueLossBPS = _minHLPValueLossBPS;
  }

  function withdrawGlp(
    WithdrawGlpParams[] calldata _params
  ) external onlyWhitelisted returns (WithdrawGlpResult[] memory returnData) {
    // SLOADS, gas opt.
    IVaultStorage _vaultStorage = vaultStorage;
    IERC20Upgradeable _sglp = sglp;

    // Validate input
    uint256 totalGlpAccum = 0;
    for (uint256 i = 0; i < _params.length; ) {
      if (_params[i].token == address(0)) {
        revert RebalanceHLPService_InvalidTokenAddress();
      }
      totalGlpAccum += _params[i].glpAmount;
      unchecked {
        ++i;
      }
    }
    if (_vaultStorage.hlpLiquidity(address(sglp)) < totalGlpAccum) {
      revert RebalanceHLPService_InvalidTokenAmount();
    }
    // Get current HLP value
    uint256 totalHlpValueBefore = calculator.getHLPValueE30(true);
    returnData = new WithdrawGlpResult[](_params.length);
    for (uint256 i = 0; i < _params.length; ) {
      // Set default for return data
      returnData[i].token = _params[i].token;
      returnData[i].amount = 0;
      // Get token from vault, remove HLP liq.
      _vaultStorage.pushToken(address(_sglp), address(this), _params[i].glpAmount);
      _vaultStorage.removeHLPLiquidity(address(_sglp), _params[i].glpAmount);

      // Unstake n redeem GLP
      _sglp.safeIncreaseAllowance(address(glpManager), _params[i].glpAmount);
      returnData[i].amount += rewardRouter.unstakeAndRedeemGlp(
        _params[i].token,
        _params[i].glpAmount,
        _params[i].minOut,
        address(_vaultStorage)
      );

      // Update accounting
      _vaultStorage.pullToken(_params[i].token);
      _vaultStorage.addHLPLiquidity(_params[i].token, returnData[i].amount);
      unchecked {
        ++i;
      }
    }
    _validateHLPValue(totalHlpValueBefore);
  }

  function addGlp(AddGlpParams[] calldata _params) external onlyWhitelisted returns (uint256 receivedGlp) {
    // SLOADS, gas opt.
    IERC20Upgradeable _sglp = sglp;
    IVaultStorage _vaultStorage = vaultStorage;
    ISwitchCollateralRouter _switchRouter = switchRouter;

    // Validate input
    for (uint256 i = 0; i < _params.length; ) {
      if (_params[i].token == address(0)) {
        revert RebalanceHLPService_InvalidTokenAddress();
      }
      if ((_params[i].amount > _vaultStorage.hlpLiquidity(_params[i].token)) || (_params[i].amount == 0)) {
        revert RebalanceHLPService_InvalidTokenAmount();
      }
      unchecked {
        ++i;
      }
    }
    // Get current HLP value
    uint256 totalHlpValueBefore = calculator.getHLPValueE30(true);
    receivedGlp = 0;
    for (uint256 i = 0; i < _params.length; ) {
      IERC20Upgradeable rebalanceToken;
      uint256 realizedAmountToAdd;
      if (_params[i].tokenMedium != address(0)) {
        address[] memory path = new address[](2);
        path[0] = _params[i].token;
        path[1] = _params[i].tokenMedium;

        // Get first Token from vault, remove HLP liq.
        _vaultStorage.pushToken(_params[i].token, address(_switchRouter), _params[i].amount);
        _vaultStorage.removeHLPLiquidity(_params[i].token, _params[i].amount);

        rebalanceToken = IERC20Upgradeable(_params[i].tokenMedium);
        realizedAmountToAdd = _switchRouter.execute(_params[i].amount, path);
      } else {
        // Get Token from vault, remove HLP liq.
        _vaultStorage.pushToken(_params[i].token, address(this), _params[i].amount);
        _vaultStorage.removeHLPLiquidity(_params[i].token, _params[i].amount);

        rebalanceToken = IERC20Upgradeable(_params[i].token);
        realizedAmountToAdd = _params[i].amount;
      }
      // Mint n stake, sanity check
      rebalanceToken.safeIncreaseAllowance(address(glpManager), realizedAmountToAdd);
      receivedGlp += rewardRouter.mintAndStakeGlp(
        address(rebalanceToken),
        realizedAmountToAdd,
        _params[i].minAmountOutUSD,
        _params[i].minAmountOutGlp
      );
      unchecked {
        ++i;
      }
    }

    // Send accum GLP back to vault
    _sglp.safeTransfer(address(vaultStorage), receivedGlp);

    // Send token back to vault, add HLP liq.
    _vaultStorage.pullToken(address(_sglp));
    _vaultStorage.addHLPLiquidity(address(_sglp), receivedGlp);

    _validateHLPValue(totalHlpValueBefore);
  }

  function swap(SwapParams memory _params) external onlyWhitelisted returns (uint256 _amountOut) {
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

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
