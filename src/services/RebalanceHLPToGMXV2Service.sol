// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// interfaces
import { IGMXExchangeRouter } from "@hmx/interfaces/gmx/IGMXExchangeRouter.sol";

contract RebalanceHLPToGMXV2Service is OwnableUpgradeable, IRebalanceHLPService {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  struct DepositParams {
    address token;
    uint256 amount;
    CreateDepositParams params;
  }

  address public exchangeRouter; // 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8
  address public depositVault; // 0xf89e77e8dc11691c9e8757e84aafbcd8a67d7a55
  uint16 public minHLPValueLossBPS;

  modifier onlyWhitelisted() {
    configStorage.validateServiceExecutor(address(this), msg.sender);
    _;
  }

  event LogSetMinHLPValueLossBPS(uint16 oldValue, uint16 newValue);

  // function initialize(
  //   address _sglp,
  //   address _rewardRouter,
  //   address _glpManager,
  //   address _vaultStorage,
  //   address _configStorage,
  //   address _calculator,
  //   address _switchCollateralRouter,
  //   uint16 _minHLPValueLossBPS
  // ) external initializer {
  //   OwnableUpgradeable.__Ownable_init();
  //   sglp = IERC20Upgradeable(_sglp);
  //   rewardRouter = IGmxRewardRouterV2(_rewardRouter);
  //   glpManager = IGmxGlpManager(_glpManager);
  //   vaultStorage = IVaultStorage(_vaultStorage);
  //   configStorage = IConfigStorage(_configStorage);
  //   calculator = ICalculator(_calculator);
  //   switchRouter = ISwitchCollateralRouter(_switchCollateralRouter);
  //   minHLPValueLossBPS = _minHLPValueLossBPS;
  // }

  function executeDeposits(DepositParams[] calldata depositParams) external {
    for (uint256 i; i < params.length; i++) {
      _vaultStorage.pushToken(depositParams[i].token, address(this), depositParams[i].amount);
      _vaultStorage.removeHLPLiquidityOnHold(depositParams[i].token, depositParams[i].amount);

      IGMXExchangeRouter(exchangeRouter).sendTokens(token, depositVault, amount);
      IGMXExchangeRouter(exchangeRouter).createDeposit(address(this), depositParams[i].params);
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
