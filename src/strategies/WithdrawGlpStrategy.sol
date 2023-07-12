// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IWithdrawGlpStrategy } from "@hmx/strategies/interfaces/IWithdrawGlpStrategy.sol";

contract WithdrawGlpStrategy is OwnableUpgradeable, IWithdrawGlpStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable public sglp;
  ICalculator public calculator;
  IGmxRewardRouterV2 public rewardRouter;
  IGmxGlpManager public glpManager;
  IVaultStorage public vaultStorage;

  uint16 public minTvlBPS;
  uint16 public constant BPS = 100_00;

  mapping(address => bool) public whitelistExecutors;

  event SetMinTvlBPS(uint16 _oldMinTvlBps, uint16 _newMinTvlBps);
  event SetWhitelistExecutor(address indexed _account, bool _active);

  /**
   * Modifiers
   */
  modifier onlyWhitelist() {
    if (!whitelistExecutors[msg.sender]) {
      revert WithdrawGlpStrategy_OnlyWhitelisted();
    }
    _;
  }

  function initialize(
    address _sglp,
    address _rewardRouter,
    address _vaultStorage,
    address _glpManager,
    address _calculator,
    uint16 _minTvlBPS
  ) external initializer {
    __Ownable_init();
    sglp = IERC20Upgradeable(_sglp);
    rewardRouter = IGmxRewardRouterV2(_rewardRouter);
    vaultStorage = IVaultStorage(_vaultStorage);
    glpManager = IGmxGlpManager(_glpManager);
    calculator = ICalculator(_calculator);
    minTvlBPS = _minTvlBPS;
  }

  function setWhiteListExecutor(address _executor, bool _active) external onlyOwner {
    if (_executor == address(0)) revert WithdrawGlpStrategy_AddressIsZero();
    whitelistExecutors[_executor] = _active;
    emit SetWhitelistExecutor(_executor, _active);
  }

  function setMinTvlBPS(uint16 _newMinTvlBps) external onlyOwner {
    if (_newMinTvlBps == 0) revert WithdrawGlpStrategy_AmountIsZero();
    emit SetMinTvlBPS(minTvlBPS, _newMinTvlBps);
    minTvlBPS = _newMinTvlBps;
  }

  function execute(ExecuteParams[] calldata _params) external onlyWhitelist returns (uint256 amountOut) {
    if (_params.length == 0) revert WithdrawGlpStrategy_ParamsIsEmpty();

    // SLOAD
    IVaultStorage _vaultStorage = vaultStorage;
    IERC20Upgradeable _sglp = sglp;
    ICalculator _calculator = calculator;

    uint256 hlpValueBefore = _calculator.getHLPValueE30(true);
    for (uint i = 0; i < _params.length; ) {
      // ignore if either value is zero
      if (_params[i].token == address(0) || _params[i].glpAmount == 0) {
        continue;
      }
      // declare struct to pass to cook()
      IVaultStorage.CookParams[] memory cookParams = new IVaultStorage.CookParams[](2);

      // build calldata
      bytes memory _calldataApproveGlpManager = abi.encodeWithSelector(
        IERC20Upgradeable.approve.selector,
        address(glpManager),
        _params[i].glpAmount
      );
      cookParams[0] = IVaultStorage.CookParams(_params[i].token, address(_sglp), _calldataApproveGlpManager);

      bytes memory _callData = abi.encodeWithSelector(
        IGmxRewardRouterV2.unstakeAndRedeemGlp.selector,
        _params[i].token,
        _params[i].glpAmount,
        _params[i].minOut,
        address(_vaultStorage)
      );
      cookParams[1] = IVaultStorage.CookParams(_params[i].token, address(rewardRouter), _callData);

      // withdraw sGLP from GMX
      bytes[] memory returnData = vaultStorage.cook(cookParams);
      uint256 receivedAmount = abi.decode(returnData[cookParams.length - 1], (uint256));
      amountOut += receivedAmount;

      // update accounting
      _vaultStorage.pullToken(address(_sglp));
      _vaultStorage.removeHLPLiquidity(address(_sglp), _params[i].glpAmount);
      _vaultStorage.pullToken(_params[i].token);
      _vaultStorage.addHLPLiquidity(_params[i].token, receivedAmount);

      unchecked {
        ++i;
      }
    }
    if (_calculator.getHLPValueE30(true) < hlpValueBefore) {
      uint256 diffHlp = hlpValueBefore - _calculator.getHLPValueE30(true);
      // math opt.
      if ((diffHlp * BPS) >= (minTvlBPS * hlpValueBefore)) revert WithdrawGlpStrategy_HlpTvlDropExceedMin();
    }
    return amountOut;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
