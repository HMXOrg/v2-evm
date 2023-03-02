// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "../base/Owned.sol";

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { LiquidationService } from "../services/LiquidationService.sol";

contract LiquidationHandler is Owned, ReentrancyGuard {
  /**
    EVENT
   */

  event LogSetLiquidationService(address _oldLiquidationService, address _newLiquidationService);
  event LogSetPyth(address _oldPyth, address _newPyth);
  event LogLiquidate(address _subAccount);

  /**
   * STATES
   */

  address public liquidationService;
  address public pyth;

  constructor(address _liquidationService, address _pyth) {
    // Sanity check
    IPyth(_pyth).getValidTimePeriod();

    liquidationService = _liquidationService;
    pyth = _pyth;
  }

  /**
   * SETTER
   */

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

  /**
   * CALCULATION
   */

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage.
  /// @param _subAccount The sub-account to be liquidated.
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function liquidate(address _subAccount, bytes[] memory _priceData) external {
    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // liquidate
    LiquidationService(liquidationService).liquidate(_subAccount);

    emit LogLiquidate(_subAccount);
  }
}
