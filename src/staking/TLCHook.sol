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
import { FullMath } from "@hmx/libraries/FullMath.sol";

contract TLCHook is ITradeServiceHook, OwnableUpgradeable {
  using FullMath for uint256;

  error TLCHook_Forbidden();
  error TLCHook_BadArgs();

  uint32 internal constant BPS = 100_00;

  address public tradeService;
  address public tlc;
  address public tlcStaking;

  // mapping weight with the marketIndex
  mapping(uint256 marketIndex => uint256 weight) public marketWeights;
  mapping(address whitelisted => bool isWhitelisted) public whitelistedCallers;

  modifier onlyWhitelistedCaller() {
    if (!whitelistedCallers[msg.sender]) revert TLCHook_Forbidden();
    _;
  }

  event LogSetMarketWeight(uint256 marketIndex, uint256 oldWeight, uint256 newWeight);
  event LogSetWhitelistedCaller(address indexed caller, bool isWhitelisted);

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
  ) external onlyWhitelistedCaller {
    _mintTLC(_primaryAccount, _sizeDelta, _marketIndex);
  }

  function onDecreasePosition(
    address _primaryAccount,
    uint256,
    uint256,
    uint256 _sizeDelta,
    bytes32
  ) external onlyWhitelistedCaller {
    // Do nothing
  }

  function _mintTLC(address _primaryAccount, uint256 _sizeDelta, uint256 _marketIndex) internal {
    // SLOADs
    TraderLoyaltyCredit _tlc = TraderLoyaltyCredit(tlc);
    TLCStaking _tlcStaking = TLCStaking(tlcStaking);
    // Calculate mint amount which is equal to sizeDelta but convert decimal from 1e30 to 1e18
    // This is to make the TLC token composable as ERC20 with regular 18 decimals, also wighted
    uint256 weight = marketWeights[_marketIndex] == 0 ? BPS : marketWeights[_marketIndex];
    uint256 _mintAmount = _sizeDelta.mulDiv(weight, 1e16); // 1e16 = (1e30 / 1e18) * BPS, optimized math

    _tlc.mint(address(this), _mintAmount);
    _tlc.approve(address(_tlcStaking), _mintAmount);
    _tlcStaking.deposit(_primaryAccount, _mintAmount);
  }

  function setMarketWeight(uint256 _marketIndex, uint256 _weight) external onlyOwner {
    emit LogSetMarketWeight(_marketIndex, marketWeights[_marketIndex], _weight);
    marketWeights[_marketIndex] = _weight;
  }

  function setMarketWeights(uint256[] memory _marketIndexes, uint256[] memory _weights) external onlyOwner {
    if (_marketIndexes.length != _weights.length) revert TLCHook_BadArgs();
    for (uint256 i = 0; i < _marketIndexes.length; ) {
      emit LogSetMarketWeight(_marketIndexes[i], marketWeights[_marketIndexes[i]], _weights[i]);
      marketWeights[_marketIndexes[i]] = _weights[i];
      unchecked {
        ++i;
      }
    }
  }

  function setWhitelistedCallers(address[] calldata _callers, bool[] calldata _isWhitelisteds) external onlyOwner {
    if (_callers.length != _isWhitelisteds.length) revert TLCHook_BadArgs();
    for (uint256 i = 0; i < _callers.length; ) {
      whitelistedCallers[_callers[i]] = _isWhitelisteds[i];

      emit LogSetWhitelistedCaller(_callers[i], _isWhitelisteds[i]);

      unchecked {
        ++i;
      }
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
