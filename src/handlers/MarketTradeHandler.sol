// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

// contracts
import { TradeService } from "@hmx/services/TradeService.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

// interfaces
import { IMarketTradeHandler } from "@hmx/handlers/interfaces/IMarketTradeHandler.sol";

contract MarketTradeHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, IMarketTradeHandler {
  /**
   * Events
   */
  event LogSetTradeService(address oldMarketTradeService, address newMarketTradeService);
  event LogSetPyth(address oldPyth, address newPyth);
  event LogBuy(
    address account,
    uint8 subAccountId,
    uint256 marketIndex,
    uint256 buySizeE30,
    uint256 shortDecreasingSizeE30,
    uint256 longIncreasingSizeE30
  );
  event LogSell(
    address account,
    uint8 subAccountId,
    uint256 marketIndex,
    uint256 sellSizeE30,
    uint256 longDecreasingSizeE30,
    uint256 shortIncreasingSizeE30
  );

  /**
   * States
   */
  address public tradeService;
  address public pyth;

  function initialize(address _tradeService, address _pyth) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    if (_tradeService == address(0) || _pyth == address(0)) revert IMarketTradeHandler_InvalidAddress();

    tradeService = _tradeService;
    pyth = _pyth;

    // Sanity check
    TradeService(_tradeService).perpStorage();
    IPyth(_pyth).getValidTimePeriod();
  }

  /**
   * Core Functions
   */
  /// @notice Perform buy, in which increasing position size towards long exposure.
  /// @dev Flipping from short exposure to long exposure is possible here.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account id.
  /// @param _marketIndex Market index.
  /// @param _buySizeE30 Buying size in e30 format.
  /// @param _tpToken Take profit token
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function buy(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _buySizeE30,
    address _tpToken, // NOTE: current only support GLP as profit token
    bytes[] memory _priceData
  ) external payable nonReentrant {
    if (_buySizeE30 == 0) {
      revert IMarketTradeHandler_ZeroSizeInput();
    }

    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // 0. Get position
    PerpStorage.Position memory _position = _getPosition(_account, _subAccountId, _marketIndex);

    // 1. Find the `_shortDecreasingSizeE30` and `_longIncreasingSizeE30`
    uint256 _shortDecreasingSizeE30 = 0;
    uint256 _longIncreasingSizeE30 = 0;
    {
      if (_position.positionSizeE30 < 0) {
        // If short position exists, we need to close it first

        uint256 _longPositionSizeE30 = uint256(-_position.positionSizeE30);

        if (_buySizeE30 > _longPositionSizeE30) {
          // If buy size can cover the short position size,
          // long position size should be the remaining buy size
          unchecked {
            _shortDecreasingSizeE30 = _longPositionSizeE30;
            _longIncreasingSizeE30 = _buySizeE30 - _longPositionSizeE30;
          }
        } else {
          // If buy size cannot cover the short position size,
          // just simply decrease the position
          _shortDecreasingSizeE30 = _buySizeE30;
          // can be commented to save gas
          // _longIncreasingSizeE30 = 0;
        }
      } else {
        // If short position does not exists,
        // just simply increase the long position

        // can be commented to save gas
        // _shortDecreasingSizeE30 = 0;
        _longIncreasingSizeE30 = _buySizeE30;
      }
    }

    // 2. Decrease the short position first
    if (_shortDecreasingSizeE30 > 0) {
      TradeService(tradeService).decreasePosition(
        _account,
        _subAccountId,
        _marketIndex,
        _shortDecreasingSizeE30,
        _tpToken,
        0
      );
    }

    // 3. Then, increase the long position
    if (_longIncreasingSizeE30 > 0) {
      TradeService(tradeService).increasePosition(
        _account,
        _subAccountId,
        _marketIndex,
        int256(_longIncreasingSizeE30),
        0
      );
    }

    emit LogBuy(_account, _subAccountId, _marketIndex, _buySizeE30, _shortDecreasingSizeE30, _longIncreasingSizeE30);
  }

  /// @notice Perform sell, in which increasing position size towards short exposure.
  /// @dev Flipping from long exposure to short exposure is possible here.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account id.
  /// @param _marketIndex Market index.
  /// @param _sellSizeE30 Buying size in e30 format.
  /// @param _tpToken Take profit token
  /// @param _priceData Pyth price feed data, can be derived from Pyth client SDK.
  function sell(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _sellSizeE30,
    address _tpToken, // NOTE: current only support GLP as profit token
    bytes[] memory _priceData
  ) external payable nonReentrant {
    if (_sellSizeE30 == 0) {
      revert IMarketTradeHandler_ZeroSizeInput();
    }

    // Feed Price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // 0. Get position
    PerpStorage.Position memory _position = _getPosition(_account, _subAccountId, _marketIndex);

    // 1. Find the `_longDecreasingSizeE30` and `_shortIncreasingSizeE30`
    uint256 _longDecreasingSizeE30 = 0;
    uint256 _shortIncreasingSizeE30 = 0;
    {
      if (_position.positionSizeE30 > 0) {
        // If long position exists, we need to close it first

        uint256 _longPositionSizeE30 = uint256(_position.positionSizeE30);

        if (_sellSizeE30 > _longPositionSizeE30) {
          // If sell size can cover the long position size,
          // short position size should be the remaining sell size
          unchecked {
            _longDecreasingSizeE30 = _longPositionSizeE30;
            _shortIncreasingSizeE30 = _sellSizeE30 - _longPositionSizeE30;
          }
        } else {
          // If sell size cannot cover the short position size,
          // just simply decrease the position
          _longDecreasingSizeE30 = _sellSizeE30;
          // can be commented to save gas
          // _shortIncreasingSizeE30 = 0;
        }
      } else {
        // If long position does not exists,
        // just simply increase the short position

        // can be commented to save gas
        // _longDecreasingSizeE30 = 0;
        _shortIncreasingSizeE30 = _sellSizeE30;
      }
    }

    // 2. Decrease the long position first
    if (_longDecreasingSizeE30 > 0) {
      TradeService(tradeService).decreasePosition(
        _account,
        _subAccountId,
        _marketIndex,
        _longDecreasingSizeE30,
        _tpToken,
        0
      );
    }

    // 3. Then, increase the short position
    if (_shortIncreasingSizeE30 > 0) {
      TradeService(tradeService).increasePosition(
        _account,
        _subAccountId,
        _marketIndex,
        -int256(_shortIncreasingSizeE30),
        0
      );
    }

    emit LogSell(_account, _subAccountId, _marketIndex, _sellSizeE30, _longDecreasingSizeE30, _shortIncreasingSizeE30);
  }

  /**
   * Setters
   */

  /// @notice Set new trader service contract address.
  /// @param _newTradeService New trader service contract address.
  function setTradeService(address _newTradeService) external nonReentrant onlyOwner {
    if (_newTradeService == address(0)) revert IMarketTradeHandler_InvalidAddress();
    emit LogSetTradeService(address(tradeService), _newTradeService);
    tradeService = _newTradeService;

    // Sanity check
    TradeService(_newTradeService).perpStorage();
  }

  /// @notice Set new Pyth contract address.
  /// @param _newPyth New Pyth contract address.
  function setPyth(address _newPyth) external nonReentrant onlyOwner {
    if (_newPyth == address(0)) revert IMarketTradeHandler_InvalidAddress();
    emit LogSetPyth(pyth, _newPyth);
    pyth = _newPyth;

    // Sanity check
    IPyth(_newPyth).getValidTimePeriod();
  }

  /**
   * Internal
   */

  /// @notice Calculate subAccount address on trader.
  /// @dev This uses to create subAccount address combined between Primary account and SubAccount ID.
  /// @param _primary Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @return _subAccount Trader's sub account address used for trading.
  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  /// @notice Derive positionId from sub-account and market index
  /// @param _subAccount Trader's sub account (account + subAccountId).
  /// @param _marketIndex Market index.
  /// @return _positionId
  function _getPositionId(address _subAccount, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  /// @notice Get position struct from account, subAccountId and market index
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account id.
  /// @param _marketIndex Market index.
  /// @return _position Position struct
  function _getPosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex
  ) internal view returns (PerpStorage.Position memory) {
    address _perpStorage = TradeService(tradeService).perpStorage();
    address _subAccount = _getSubAccount(_account, _subAccountId);
    bytes32 _positionId = _getPositionId(_subAccount, _marketIndex);

    return PerpStorage(_perpStorage).getPositionById(_positionId);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
