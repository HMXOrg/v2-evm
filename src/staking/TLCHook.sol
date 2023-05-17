// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";
import { MintableTokenInterface } from "@hmx/staking/interfaces/MintableTokenInterface.sol";
import { ITLCStaking } from "@hmx/staking/interfaces/ITLCStaking.sol";

contract TLCHook is ITradeServiceHook, OwnableUpgradeable {
  error TradingStakingHook_Forbidden();

  address public tradeService;
  address public tlc;
  address public tlcStaking;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert TradingStakingHook_Forbidden();
    _;
  }

  function initialize(address _tradeService, address _tlc, address _tlcStaking) external initializer {
    OwnableUpgradeable.__Ownable_init();

    tradeService = _tradeService;
    tlc = _tlc;
    tlcStaking = _tlcStaking;

    // Sanity checks
    ITradeService(tradeService).configStorage();
    MintableTokenInterface(tlc).symbol();
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
    MintableTokenInterface(tlc).mint(address(this), _mintAmount);
    MintableTokenInterface(tlc).approve(tlcStaking, _mintAmount);
    ITLCStaking(tlcStaking).deposit(_primaryAccount, _mintAmount);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
