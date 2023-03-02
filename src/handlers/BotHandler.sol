// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { Owned } from "../base/Owned.sol";
// contracts
import { TradeService } from "@services/TradeService.sol";
// interfaces
import { IBotHandler } from "@handlers/interfaces/IBotHandler.sol";

// @todo - integrate with BotHandler in another PRs
contract BotHandler is IBotHandler, Owned {
  /**
   * Events
   */
  event LogTakeMaxProfit(address indexed _account, uint256 _subAccountId, uint256 _marketIndex, address _tpToken);
  event LogSetTradeService(address _oldTradeService, address _newTradeService);
  event LogSetPositionManager(address _address, bool _allowed);
  /**
   * States
   */

  // contract who can close position in protocol.
  // contract => allowed
  mapping(address => bool) public positionManagers;
  address public tradeService;

  /**
   * Modifiers
   */

  /// @notice modifier to check msg.sender is in position manangers
  modifier onlyPositionManager() {
    if (!positionManagers[msg.sender]) revert IBotHandler_UnauthorizedSender();
    _;
  }

  constructor(address _tradeService) {
    tradeService = _tradeService;

    // Sanity check
    TradeService(_tradeService).configStorage();
  }

  /// @notice force to close position and take profit, depend on reserve value on this position
  /// @param _account position's owner
  /// @param _subAccountId sub-account that owned position
  /// @param _marketIndex market index of position
  /// @param _tpToken token that trader receive as profit
  function forceTakeMaxProfit(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    address _tpToken
  ) external onlyPositionManager {
    TradeService(tradeService).forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

    emit LogTakeMaxProfit(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice Reset trade service
  /// @param _newTradeService new trade service address
  function setTradeService(address _newTradeService) external onlyOwner {
    emit LogSetTradeService(tradeService, _newTradeService);

    tradeService = _newTradeService;

    // Sanity check
    TradeService(_newTradeService).configStorage();
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
}
