// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

// contracts
import { TradeService } from "@hmx/services/TradeService.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

/// @title BotHandler
contract BotHandler is ReentrancyGuardUpgradeable, IBotHandler, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * Events
   */
  event LogTakeMaxProfit(address indexed account, uint8 subAccountId, uint256 marketIndex, address tpToken);
  event LogDeleverage(address indexed account, uint8 subAccountId, uint256 marketIndex, address tpToken);
  event LogCloseDelistedMarketPosition(
    address indexed account,
    uint8 subAccountId,
    uint256 marketIndex,
    address tpToken
  );
  event LogLiquidate(address subAccount);
  event LogInjectTokenToPlpLiquidity(address indexed account, address token, uint256 amount);
  event LogInjectTokenToFundingFeeReserve(address indexed account, address token, uint256 amount);

  event LogSetTradeService(address oldTradeService, address newTradeService);
  event LogSetPositionManager(address account, bool allowed);
  event LogSetLiquidationService(address oldLiquidationService, address newLiquidationService);
  event LogSetPyth(address oldPyth, address newPyth);

  /**
   * States
   */

  // contract who can close position in protocol.
  // contract => allowed
  mapping(address => bool) public positionManagers;
  address public tradeService;
  address public liquidationService;
  address public pyth;

  /**
   * Modifiers
   */

  /// @notice modifier to check msg.sender is in position managers
  modifier onlyPositionManager() {
    if (!positionManagers[msg.sender]) revert IBotHandler_UnauthorizedSender();
    _;
  }

  /// @notice Initializes the BotHandler contract with the provided configuration parameters.
  /// @param _tradeService Address of the TradeService contract.
  /// @param _liquidationService Address of the LiquidationService contract.
  /// @param _pyth Address of the Pyth contract.
  function initialize(address _tradeService, address _liquidationService, address _pyth) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    // Sanity check
    ITradeService(_tradeService).configStorage();
    LiquidationService(_liquidationService).perpStorage();
    IEcoPyth(_pyth).getAssetIds();

    tradeService = _tradeService;
    liquidationService = _liquidationService;
    pyth = _pyth;
  }

  /**
   * Core Functions
   */

  /// @notice force to close position and take profit, depend on reserve value on this position
  /// @param _account position's owner
  /// @param _subAccountId sub-account that owned position
  /// @param _marketIndex market index of position
  /// @param _tpToken token that trader receive as profit
  function forceTakeMaxProfit(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable nonReentrant onlyPositionManager {
    // SLOAD
    TradeService _tradeService = TradeService(tradeService);

    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    (bool _isMaxProfit, , ) = _tradeService.forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);
    _tradeService.validateMaxProfit(_isMaxProfit);

    emit LogTakeMaxProfit(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice deleverage
  /// @param _account position's owner
  /// @param _subAccountId sub-account that owned position
  /// @param _marketIndex market index of position
  /// @param _tpToken token that trader receive as profit
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function deleverage(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable nonReentrant onlyPositionManager {
    // SLOAD
    TradeService _tradeService = TradeService(tradeService);

    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    _tradeService.validateDeleverage();
    _tradeService.forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

    emit LogDeleverage(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice forceClosePosition
  /// @param _account position's owner
  /// @param _subAccountId sub-account that owned position
  /// @param _marketIndex market index of position
  /// @param _tpToken token that trader receive as profit
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function closeDelistedMarketPosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable nonReentrant onlyPositionManager {
    // SLOAD
    TradeService _tradeService = TradeService(tradeService);

    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    _tradeService.validateMarketDelisted(_marketIndex);
    _tradeService.forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

    emit LogCloseDelistedMarketPosition(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage.
  /// @param _subAccount The sub-account to be liquidated.
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function liquidate(
    address _subAccount,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable nonReentrant onlyPositionManager {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    // liquidate
    LiquidationService(liquidationService).liquidate(_subAccount, msg.sender);

    emit LogLiquidate(_subAccount);
  }

  /// @notice convert all tokens on funding fee reserve to stable token (USDC)
  /// @param _stableToken target token that will convert all funding fee reserves to
  struct ConvertFundingFeeReserveLocalVars {
    address[] collateralTokens;
    address collatToken;
    uint256 collatTokenPrice;
    uint256 fundingFeeReserve;
    uint256 convertedStableAmount;
  }

  function convertFundingFeeReserve(
    address _stableToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable nonReentrant onlyOwner {
    ConvertFundingFeeReserveLocalVars memory vars;
    // SLOAD
    TradeService _tradeService = TradeService(tradeService);

    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(_tradeService.configStorage());
    VaultStorage _vaultStorage = VaultStorage(_tradeService.vaultStorage());
    OracleMiddleware _oracle = OracleMiddleware(_configStorage.oracle());

    // Get stable token price
    (uint256 _stableTokenPrice, ) = _oracle.getLatestPrice(_configStorage.tokenAssetIds(_stableToken), false);

    // Loop through collateral lists
    // And do accounting to swap token on funding fee reserve with plp liquidity

    vars.collateralTokens = _configStorage.getCollateralTokens();
    uint256 _len = vars.collateralTokens.length;
    for (uint256 _i; _i < _len; ) {
      vars.collatToken = vars.collateralTokens[_i];
      if (_stableToken != vars.collatToken) {
        vars.fundingFeeReserve = _vaultStorage.fundingFeeReserve(vars.collatToken);

        if (vars.fundingFeeReserve > 0) {
          (vars.collatTokenPrice, ) = _oracle.getLatestPrice(_configStorage.tokenAssetIds(vars.collatToken), false);

          // stable token amount = funding fee reserve value / stable price
          vars.convertedStableAmount =
            (vars.fundingFeeReserve *
              vars.collatTokenPrice *
              (10 ** _configStorage.getAssetTokenDecimal(_stableToken))) /
            (_stableTokenPrice * (10 ** _configStorage.getAssetTokenDecimal(vars.collatToken)));

          if (_vaultStorage.plpLiquidity(_stableToken) < vars.convertedStableAmount)
            revert IBotHandler_InsufficientLiquidity();

          // funding fee should be reduced while liquidity should be increased
          _vaultStorage.convertFundingFeeReserveWithPLP(
            vars.collatToken,
            _stableToken,
            vars.fundingFeeReserve,
            vars.convertedStableAmount
          );
        }
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @notice This function transfers tokens to the vault storage and performs accounting.
  /// @param _token The address of the token to be transferred.
  /// @param _amount The amount of tokens to be transferred.
  function injectTokenToPlpLiquidity(address _token, uint256 _amount) external nonReentrant onlyOwner {
    VaultStorage _vaultStorage = VaultStorage(ITradeService(tradeService).vaultStorage());

    // transfer token
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(_vaultStorage), _amount);

    // do accounting on vault storage
    _vaultStorage.addPLPLiquidity(_token, _amount);
    _vaultStorage.pullToken(_token);

    emit LogInjectTokenToPlpLiquidity(msg.sender, _token, _amount);
  }

  /// @notice This function transfers tokens to the vault storage and performs accounting.
  /// @param _token The address of the token to be transferred.
  /// @param _amount The amount of tokens to be transferred.
  function injectTokenToFundingFeeReserve(address _token, uint256 _amount) external nonReentrant onlyOwner {
    VaultStorage _vaultStorage = VaultStorage(ITradeService(tradeService).vaultStorage());

    // transfer token
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(_vaultStorage), _amount);

    // do accounting on vault storage
    _vaultStorage.addFundingFee(_token, _amount);
    _vaultStorage.pullToken(_token);

    emit LogInjectTokenToFundingFeeReserve(msg.sender, _token, _amount);
  }

  /// @notice Reset trade service
  /// @param _newTradeService new trade service address
  function setTradeService(address _newTradeService) external nonReentrant onlyOwner {
    emit LogSetTradeService(tradeService, _newTradeService);

    tradeService = _newTradeService;

    // Sanity check
    TradeService(_newTradeService).configStorage();
  }

  /// @notice This function use to set address who can close position when emergency happen
  /// @param _addresses list of address that we allow
  /// @param _isAllowed flag to allow / disallow list of address to close position
  function setPositionManagers(address[] calldata _addresses, bool _isAllowed) external nonReentrant onlyOwner {
    uint256 _len = _addresses.length;
    address _address;
    for (uint256 _i; _i < _len; ) {
      _address = _addresses[_i];
      positionManagers[_address] = _isAllowed;

      emit LogSetPositionManager(_address, _isAllowed);

      unchecked {
        ++_i;
      }
    }
  }

  /// @notice Set new liquidation service contract address.
  /// @param _newLiquidationService New liquidation service contract address.
  function setLiquidationService(address _newLiquidationService) external nonReentrant onlyOwner {
    // Sanity check
    LiquidationService(_newLiquidationService).perpStorage();
    emit LogSetLiquidationService(address(liquidationService), _newLiquidationService);
    liquidationService = _newLiquidationService;
  }

  /// @notice Set new Pyth contract address.
  /// @param _pyth New Pyth contract address.
  function setPyth(address _pyth) external nonReentrant onlyOwner {
    // Sanity check
    IEcoPyth(_pyth).getAssetIds();
    emit LogSetPyth(pyth, _pyth);
    pyth = _pyth;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
