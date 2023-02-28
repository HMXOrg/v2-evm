// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IBotHandler } from "./interfaces/IBotHandler.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";

import { Owned } from "../base/Owned.sol";

// @todo - integrate with BotHandler in another PRs
contract BotHandler is IBotHandler, Owned {
  /**
   * Events
   */

  event LogTakeMaxProfit(address indexed _account, uint256 _subAccountId, uint256 _marketIndex, address _tpToken);

  /**
   * States
   */

  // contract who can close position in protocol.
  // contract => allowed
  mapping(address => bool) positionManagers;
  address tradeService;

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
    ITradeService(_tradeService).configStorage();
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
    ITradeService(tradeService).forceClosePosition(_account, _subAccountId, _marketIndex, _tpToken);

    emit LogTakeMaxProfit(_account, _subAccountId, _marketIndex, _tpToken);
  }

  /// @notice This function use to set address who can close position when emergency happen
  /// @param _addresses list of address that we allow
  /// @param _isAllowed flag to allow / disallow list of address to close position
  function setPositionManagers(address[] calldata _addresses, bool _isAllowed) external onlyOwner {
    uint256 _len = _addresses.length;
    for (uint256 _i; _i < _len; ) {
      positionManagers[_addresses[_i]] = _isAllowed;
      unchecked {
        ++_i;
      }
    }
  }
}
