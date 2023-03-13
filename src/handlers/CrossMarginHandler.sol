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
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IWNative } from "../interfaces/IWNative.sol";

contract CrossMarginHandler is Owned, ReentrancyGuard, ICrossMarginHandler {
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
    IPyth(_pyth).getValidTimePeriod();
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
    IPyth(_pyth).getValidTimePeriod();
  }

  /**
   * CALCULATION
   */

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to call deposit function on service and calculate new trader balance when they depositing token as collateral.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _account,
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
      IWNative(_token).deposit{ value: _amount }();
      // Transfer those wNative token from this contract to VaultStorage
      ERC20(_token).safeTransfer(_crossMarginService.vaultStorage(), _amount);
    } else {
      // Transfer depositing token from trader's wallet to VaultStorage
      ERC20(_token).safeTransferFrom(msg.sender, _crossMarginService.vaultStorage(), _amount);
    }

    // Call service to deposit collateral
    _crossMarginService.depositCollateral(_account, _subAccountId, _token, _amount);

    emit LogDepositCollateral(_account, _subAccountId, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to call withdraw function on service and calculate new trader balance when they withdrawing token as collateral.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  /// @param _priceData Price update data
  function withdrawCollateral(
    address _account,
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    bytes[] memory _priceData
  ) external nonReentrant onlyAcceptedToken(_token) {
    // Call update oracle price
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // Call service to withdraw collateral
    CrossMarginService(crossMarginService).withdrawCollateral(_account, _subAccountId, _token, _amount);

    emit LogWithdrawCollateral(_account, _subAccountId, _token, _amount);
  }

  // /// @notice Transfer in ETH from user to be used as execution fee
  // /// @dev The received ETH will be wrapped into WETH and store in this contract for later use.
  // function _transferInETH() private {
  //   if (_shouldWrap) {
  //     if (msg.value != _amountIn + executionOrderFee) {
  //       revert ILiquidityHandler_InCorrectValueTransfer();
  //     }
  //   } else {
  //     if (msg.value != executionOrderFee) revert ILiquidityHandler_InCorrectValueTransfer();
  //     IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
  //   }

  //   IWNative(ConfigStorage(LiquidityService(liquidityService).configStorage()).weth()).deposit{ value: msg.value }();
  // }

  // receive() external payable {
  //   if (msg.sender != ConfigStorage(LiquidityService(liquidityService).configStorage()).weth())
  //     revert ILiquidityHandler_InvalidSender();
  // }
}
