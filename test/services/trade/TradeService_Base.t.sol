// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "../../base/BaseTest.sol";

import { TradeService } from "../../../src/services/TradeService.sol";

abstract contract TradeService_Base is BaseTest {
  TradeService tradeService;

  function setUp() public virtual {
    tradeService = new TradeService(
      address(configStorage),
      address(perpStorage),
      address(vaultStorage),
      address(mockCalculator)
    );
  }
}
