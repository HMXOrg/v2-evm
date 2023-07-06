// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ITradeServiceHook } from "../services/interfaces/ITradeServiceHook.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { ITradingStaking } from "./interfaces/ITradingStaking.sol";
import { TraderLoyaltyCredit } from "@hmx/tokens/TraderLoyaltyCredit.sol";
import { TLCStaking } from "@hmx/staking/TLCStaking.sol";
import { FullMath } from "../libraries/FullMath.sol";

contract TLCHook is ITradeServiceHook, OwnableUpgradeable {
  using FullMath for uint256;

  error TLCHook_Forbidden();

  uint256 internal constant BPS = 10_000;

  address public tradeService;
  address public tlc;
  address public tlcStaking;

  // mapping weight with the marketIndex
  mapping(uint256 marketIndex => uint256 weight) public marketWeights;

  modifier onlyTradeService() {
    if (msg.sender != tradeService) revert TLCHook_Forbidden();
    _;
  }

  event LogSetMarketWeight(uint256 marketIndex, uint256 oldWeight, uint256 newWeight);

  function initialize(address _tradeService, address _tlc, address _tlcStaking) external initializer {
    OwnableUpgradeable.__Ownable_init();

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
    uint256 _marketIndex,
    uint256 _sizeDelta,
    bytes32
  ) external onlyTradeService {
    _mintTLC(_primaryAccount, _sizeDelta, _marketIndex);
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

  function _mintTLC(address _primaryAccount, uint256 _sizeDelta, uint256 _marketIndex) internal {
    // SLOADs
    TraderLoyaltyCredit _tlc = TraderLoyaltyCredit(tlc);
    TLCStaking _tlcStaking = TLCStaking(tlcStaking);
    // Calculate mint amount which is equal to sizeDelta but convert decimal from 1e30 to 1e18
    // This is to make the TLC token composable as ERC20 with regular 18 decimals, also wighted
    uint256 weight = marketWeights[_marketIndex] == 0 ? BPS : marketWeights[_marketIndex];
    uint256 _mintAmount = _sizeDelta.mulDiv(weight, 1e12) / BPS;

    _tlc.mint(address(this), _mintAmount);
    _tlc.approve(address(_tlcStaking), _mintAmount);
    _tlcStaking.deposit(_primaryAccount, _mintAmount);
  }

  function setMarketWeight(uint256 _marketIndex, uint256 _weight) external onlyOwner {
    uint256 oldWeight = marketWeights[_marketIndex];
    marketWeights[_marketIndex] = _weight;
    emit LogSetMarketWeight(_marketIndex, oldWeight, _weight);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
