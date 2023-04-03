// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

// interfaces
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { IPyth } from "lib/pyth-sdk-solidity/IPyth.sol";

// contracts
import { Owned } from "@hmx/base/Owned.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

// @todo - integrate with BotHandler in another PRs
contract BotHandler is ReentrancyGuard, IBotHandler, Owned {
  /**
   * Events
   */
  event LogTakeMaxProfit(address indexed _account, uint8 _subAccountId, uint256 _marketIndex, address _tpToken);
  event LogDeleverage(address indexed _account, uint8 _subAccountId, uint256 _marketIndex, address _tpToken);
  event LogCloseDelistedMarketPosition(
    address indexed _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken
  );
  event LogLiquidate(address _subAccount);

  event LogSetTradeService(address _oldTradeService, address _newTradeService);
  event LogSetPositionManager(address _address, bool _allowed);
  event LogSetLiquidationService(address _oldLiquidationService, address _newLiquidationService);
  event LogSetPyth(address _oldPyth, address _newPyth);

  /**
   * Structs
   */
  struct ConvertFundingFeeReserveInputs {
    uint256 stableTokenPrice;
    uint256 fundingFeeReserve;
    uint256 tokenPrice;
    uint256 fundingFeeReserveValue;
    uint256 stableTokenAmount;
    address[] collateralTokens;
    bytes32 stableTokenAssetId;
    bytes32 tokenAssetId;
    uint8 stableTokenDecimal;
    uint8 tokenDecimal;
  }

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

  constructor(address _tradeService, address _liquidationService, address _pyth) {
    // Sanity check
    ITradeService(_tradeService).configStorage();
    LiquidationService(_liquidationService).perpStorage();
    // IPyth(_pyth).getUpdateFee(new bytes[](0));

    tradeService = _tradeService;
    liquidationService = _liquidationService;
    pyth = _pyth;
  }

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
    bytes[] memory _priceData
  ) external payable nonReentrant onlyPositionManager {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    (bool _isMaxProfit, , ) = TradeService(tradeService).forceClosePosition(
      _account,
      _subAccountId,
      _marketIndex,
      _tpToken
    );

    TradeService(tradeService).validateMaxProfit(_isMaxProfit);

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
    bytes[] memory _priceData
  ) external payable nonReentrant onlyPositionManager {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    TradeService(tradeService).validateDeleverage();

    TradeService(tradeService).forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

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
    bytes[] memory _priceData
  ) external payable nonReentrant onlyPositionManager {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    TradeService(tradeService).validateMarketDelisted(_marketIndex);

    TradeService(tradeService).forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

    emit LogCloseDelistedMarketPosition(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage.
  /// @param _subAccount The sub-account to be liquidated.
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function liquidate(address _subAccount, bytes[] memory _priceData) external payable nonReentrant onlyPositionManager {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // liquidate
    LiquidationService(liquidationService).liquidate(_subAccount, msg.sender);

    emit LogLiquidate(_subAccount);
  }

  /// @notice convert all tokens on funding fee reserve to stable token (USDC)
  /// @param _stableToken target token that will convert all funding fee reserves to
  function convertFundingFeeReserve(
    address _stableToken,
    bytes[] memory _priceData
  ) external payable nonReentrant onlyOwner {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(ITradeService(tradeService).configStorage());
    VaultStorage _vaultStorage = VaultStorage(ITradeService(tradeService).vaultStorage());
    OracleMiddleware _oracle = OracleMiddleware(_configStorage.oracle());

    ConvertFundingFeeReserveInputs memory _vars;

    _vars.collateralTokens = _configStorage.getCollateralTokens();

    // Get stable token price
    _vars.stableTokenAssetId = _configStorage.tokenAssetIds(_stableToken);
    _vars.stableTokenDecimal = _configStorage.getAssetTokenDecimal(_stableToken);
    (_vars.stableTokenPrice, ) = _oracle.getLatestPrice(_vars.stableTokenAssetId, false);

    // Loop through collateral lists
    // And do accounting to swap token on funding fee reserve with plp liquidity
    for (uint256 i; i < _vars.collateralTokens.length; ) {
      _vars.fundingFeeReserve = _vaultStorage.fundingFeeReserve(_vars.collateralTokens[i]);
      _vars.tokenAssetId = _configStorage.tokenAssetIds(_vars.collateralTokens[i]);
      _vars.tokenDecimal = _configStorage.getAssetTokenDecimal(_vars.collateralTokens[i]);

      if (_stableToken != _vars.collateralTokens[i] && _vars.fundingFeeReserve > 0) {
        (_vars.tokenPrice, ) = _oracle.getLatestPrice(_vars.tokenAssetId, false);
        _vars.fundingFeeReserveValue = (_vars.fundingFeeReserve * _vars.tokenPrice) / (10 ** _vars.tokenDecimal);
        _vars.stableTokenAmount =
          (_vars.fundingFeeReserveValue * (10 ** _vars.stableTokenDecimal)) /
          _vars.stableTokenPrice;

        if (_vaultStorage.plpLiquidity(_stableToken) < _vars.stableTokenAmount)
          revert IBotHandler_InsufficientLiquidity();

        _vaultStorage.convertFundingFeeReserveWithPLP(
          _vars.collateralTokens[i],
          _stableToken,
          _vars.fundingFeeReserve,
          _vars.stableTokenAmount
        );
      }

      unchecked {
        ++i;
      }
    }
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
  function setLiquidationService(address _newLiquidationService) external onlyOwner {
    // Sanity check
    LiquidationService(_newLiquidationService).perpStorage();

    address _liquidationService = liquidationService;

    liquidationService = _newLiquidationService;

    emit LogSetLiquidationService(address(_liquidationService), _newLiquidationService);
  }

  /// @notice Set new Pyth contract address.
  /// @param _newPyth New Pyth contract address.
  function setPyth(address _newPyth) external onlyOwner {
    // Sanity check
    IPyth(_newPyth).getUpdateFee(new bytes[](0));

    pyth = _newPyth;

    emit LogSetPyth(pyth, _newPyth);
  }
}
