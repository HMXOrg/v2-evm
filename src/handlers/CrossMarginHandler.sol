// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
// base
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "@hmx/base/Owned.sol";

// interfaces
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IWNative } from "../interfaces/IWNative.sol";

import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

contract CrossMarginHandler is Owned, ReentrancyGuard, ICrossMarginHandler {
  uint64 internal constant RATE_PRECISION = 1e18;
  using SafeERC20 for ERC20;

  /**
   * EVENTS
   */
  event LogSetCrossMarginService(address indexed oldCrossMarginService, address newCrossMarginService);
  event LogSetPyth(address indexed oldPyth, address newPyth);
  event LogDepositCollateral(
    address indexed primaryAccount,
    uint256 indexed subAccountId,
    address token,
    uint256 amount
  );
  event LogWithdrawCollateral(
    address indexed primaryAccount,
    uint256 indexed subAccountId,
    address token,
    uint256 amount
  );

  /**
   * STATES
   */
  address public crossMarginService;
  address public pyth;

  constructor(address _crossMarginService, address _pyth) {
    crossMarginService = _crossMarginService;
    pyth = _pyth;

    // Sanity check
    CrossMarginService(_crossMarginService).vaultStorage();
    IPyth(_pyth).getUpdateFee(new bytes[](0));
  }

  /**
   * MODIFIER
   */

  // NOTE: Validate only accepted collateral token to be deposited
  modifier onlyAcceptedToken(address _token) {
    ConfigStorage(CrossMarginService(crossMarginService).configStorage()).validateAcceptedCollateral(_token);
    _;
  }

  /**
   * SETTER
   */

  /// @notice Set new CrossMarginService contract address.
  /// @param _crossMarginService New CrossMarginService contract address.
  function setCrossMarginService(address _crossMarginService) external nonReentrant onlyOwner {
    if (_crossMarginService == address(0)) revert ICrossMarginHandler_InvalidAddress();
    emit LogSetCrossMarginService(crossMarginService, _crossMarginService);
    crossMarginService = _crossMarginService;

    // Sanity check
    CrossMarginService(_crossMarginService).vaultStorage();
  }

  /// @notice Set new Pyth contract address.
  /// @param _pyth New Pyth contract address.
  function setPyth(address _pyth) external nonReentrant onlyOwner {
    if (_pyth == address(0)) revert ICrossMarginHandler_InvalidAddress();
    emit LogSetPyth(pyth, _pyth);
    pyth = _pyth;

    // Sanity check
    IPyth(_pyth).getUpdateFee(new bytes[](0));
  }

  /**
   * CALCULATION
   */

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to call deposit function on service and calculate new trader balance when they depositing token as collateral.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    bool _shouldWrap
  ) external payable nonReentrant onlyAcceptedToken(_token) {
    CrossMarginService _crossMarginService = CrossMarginService(crossMarginService);

    if (_shouldWrap) {
      // Prevent mismatch msgValue and the input amount
      if (msg.value != _amount) {
        revert ICrossMarginHandler_MismatchMsgValue();
      }

      // Wrap the native to wNative. The _token must be wNative.
      // If not, it would revert transfer amount exceed on the next line.
      // slither-disable-next-line arbitrary-send-eth
      IWNative(_token).deposit{ value: _amount }();
      // Transfer those wNative token from this contract to VaultStorage
      ERC20(_token).safeTransfer(_crossMarginService.vaultStorage(), _amount);
    } else {
      // Transfer depositing token from trader's wallet to VaultStorage
      ERC20(_token).safeTransferFrom(msg.sender, _crossMarginService.vaultStorage(), _amount);
    }

    // Call service to deposit collateral
    _crossMarginService.depositCollateral(msg.sender, _subAccountId, _token, _amount);

    emit LogDepositCollateral(msg.sender, _subAccountId, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to call withdraw function on service and calculate new trader balance when they withdrawing token as collateral.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  /// @param _priceData Price update data
  function withdrawCollateral(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    bytes[] memory _priceData,
    bool _shouldUnwrap
  ) external payable nonReentrant onlyAcceptedToken(_token) {
    // Call update oracle price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    CrossMarginService _crossMarginService = CrossMarginService(crossMarginService);

    // Call service to withdraw collateral
    if (_shouldUnwrap) {
      // Withdraw wNative straight to this contract first.
      _crossMarginService.withdrawCollateral(msg.sender, _subAccountId, _token, _amount, address(this));
      // Then we unwrap the wNative token. The receiving amount should be the exact same as _amount. (No fee deducted when withdraw)
      IWNative(_token).withdraw(_amount);
      // Finally, transfer those native token right to user.
      // slither-disable-next-line arbitrary-send-eth
      payable(msg.sender).transfer(_amount);
    } else {
      // Withdraw _token straight to the user
      _crossMarginService.withdrawCollateral(msg.sender, _subAccountId, _token, _amount, msg.sender);
    }

    emit LogWithdrawCollateral(msg.sender, _subAccountId, _token, _amount);
  }

  /// @notice Check funding fee surplus and transfer to PLP
  /// @dev Check if value on funding fee reserve have exceed balance for paying to traders
  ///      - If yes means exceed value are the surplus for platform and can be booked to PLP
  function withdrawFundingFeeSurplus(
    address _stableToken,
    bytes[] memory _priceData
  ) external payable nonReentrant onlyOwner {
    uint256 _updateFee = IPyth(pyth).getUpdateFee(_priceData);
    if (msg.value != _updateFee) {
      revert ICrossMarginHandler_InCorrectValueTransfer();
    }

    // Call update oracle price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    CrossMarginService _crossMarginService = CrossMarginService(crossMarginService);
    _crossMarginService.withdrawFundingFeeSurplus(_stableToken);
  }

  receive() external payable {
    // @dev Cannot enable this check due to Solidity Fallback Function Gas Limit introduced in 0.8.17.
    // ref - https://stackoverflow.com/questions/74930609/solidity-fallback-function-gas-limit
    // require(msg.sender == ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth());
  }
}
