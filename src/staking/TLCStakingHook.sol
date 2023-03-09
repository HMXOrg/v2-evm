// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";
import { TraderLoyaltyCredit } from "@hmx/tokens/TraderLoyaltyCredit.sol";

contract TLCStakingHook is ITradeServiceHook, Owned {
  error TradingStakingHook_Forbidden();

  address public tlcStaking;
  address public tradeService;
  address public tlc;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert TradingStakingHook_Forbidden();
    _;
  }

  constructor(address _tlcStaking, address _tradeService, address _tlc) {
    tlcStaking = _tlcStaking;
    tradeService = _tradeService;
    tlc = _tlc;

    // Sanity checks
    ITradingStaking(tlcStaking).isRewarder(address(0));
    ITradeService(tradeService).configStorage();
    TraderLoyaltyCredit(tlc).symbol();
  }

  function onIncreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) external onlyTradeService {
    _mintAndDeposit(_primaryAccount, _marketIndex, _sizeDelta);
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) external onlyTradeService {
    _mintAndDeposit(_primaryAccount, _marketIndex, _sizeDelta);
  }

  function _mintAndDeposit(address _primaryAccount, uint256 _marketIndex, uint256 _sizeDelta) internal {
    // Calculate mint amount which is equal to sizeDelta but convert decimal from 1e30 to 1e18
    // This is to make the TLC token composable as ERC20 with regular 18 decimals
    uint256 _mintAmount = _sizeDelta / 1e12;
    TraderLoyaltyCredit(tlc).mint(address(this), _mintAmount);
    TraderLoyaltyCredit(tlc).approve(tlcStaking, _mintAmount);
    ITradingStaking(tlcStaking).deposit(_primaryAccount, _marketIndex, _mintAmount);
  }
}
