// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";
import { TraderLoyaltyCredit } from "@hmx/tokens/TraderLoyaltyCredit.sol";
import { TLCStaking } from "@hmx/staking/TLCStaking.sol";

contract TLCHook is ITradeServiceHook, Owned {
  error TradingStakingHook_Forbidden();

  address public tradeService;
  address public tlc;
  address public tlcStaking;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert TradingStakingHook_Forbidden();
    _;
  }

  constructor(address _tradeService, address _tlc, address _tlcStaking) {
    tradeService = _tradeService;
    tlc = _tlc;
    tlcStaking = _tlcStaking;

    // Sanity checks
    ITradeService(tradeService).configStorage();
    TraderLoyaltyCredit(tlc).symbol();
  }

  function onIncreasePosition(
    address _primaryAccount,
    uint256,
    uint256,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    _mintTLC(_primaryAccount, _sizeDelta);
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    // Do nothing
  }

  function _mintTLC(address _primaryAccount, uint256 _sizeDelta) internal {
    // Calculate mint amount which is equal to sizeDelta but convert decimal from 1e30 to 1e18
    // This is to make the TLC token composable as ERC20 with regular 18 decimals
    uint256 _mintAmount = _sizeDelta / 1e12;
    TraderLoyaltyCredit(tlc).mint(address(this), _mintAmount);
    TraderLoyaltyCredit(tlc).approve(tlcStaking, _mintAmount);
    TLCStaking(tlcStaking).deposit(_primaryAccount, _mintAmount);
  }
}
