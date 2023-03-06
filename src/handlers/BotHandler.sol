// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IBotHandler } from "./interfaces/IBotHandler.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { LiquidationService } from "../services/LiquidationService.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { Owned } from "../base/Owned.sol";

// @todo - integrate with BotHandler in another PRs
contract BotHandler is IBotHandler, Owned {
  /**
   * Events
   */
  event LogTakeMaxProfit(address indexed _account, uint8 _subAccountId, uint256 _marketIndex, address _tpToken);
  event LogLiquidate(address _subAccount);

  event LogSetTradeService(address _oldTradeService, address _newTradeService);
  event LogSetPositionManager(address _address, bool _allowed);
  event LogSetLiquidationService(address _oldLiquidationService, address _newLiquidationService);
  event LogSetPyth(address _oldPyth, address _newPyth);

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

  /// @notice modifier to check msg.sender is in position manangers
  modifier onlyPositionManager() {
    if (!positionManagers[msg.sender]) revert IBotHandler_UnauthorizedSender();
    _;
  }

  constructor(address _tradeService, address _liquidationService, address _pyth) {
    // Sanity check
    ITradeService(_tradeService).configStorage();
    LiquidationService(_liquidationService).perpStorage();
    IPyth(_pyth).getValidTimePeriod();

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
    address _tpToken
  ) external onlyPositionManager {
    ITradeService(tradeService).forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

    emit LogTakeMaxProfit(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage.
  /// @param _subAccount The sub-account to be liquidated.
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function liquidate(address _subAccount, bytes[] memory _priceData) external onlyPositionManager {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // liquidate
    LiquidationService(liquidationService).liquidate(_subAccount);

    emit LogLiquidate(_subAccount);
  }

  /// @notice Reset trade service
  /// @param _newTradeService new trade service address
  function setTradeService(address _newTradeService) external onlyOwner {
    emit LogSetTradeService(tradeService, _newTradeService);

    tradeService = _newTradeService;

    // Sanity check
    ITradeService(_newTradeService).configStorage();
  }

  /// @notice This function use to set address who can close position when emergency happen
  /// @param _addresses list of address that we allow
  /// @param _isAllowed flag to allow / disallow list of address to close position
  function setPositionManagers(address[] calldata _addresses, bool _isAllowed) external onlyOwner {
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
    IPyth(_newPyth).getValidTimePeriod();

    pyth = _newPyth;

    emit LogSetPyth(pyth, _newPyth);
  }
}
