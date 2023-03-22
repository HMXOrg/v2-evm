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
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";

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

  // /// @notice Check funding fee surplus for transfer to PLP
  // function withdrawFundingFeeSurplus() external nonReentrant onlyOwner {
  //   ConfigStorage _configStorage = ConfigStorage(CrossMarginService(crossMarginService).configStorage());
  //   PerpStorage _perpStorage = PerpStorage(CrossMarginService(crossMarginService).perpStorage());
  //   VaultStorage _vaultStorage = VaultStorage(CrossMarginService(crossMarginService).vaultStorage());
  //   OracleMiddleware _oracle = OracleMiddleware(_configStorage.oracle());

  //   // Loop through all markets and sum accum of funding fee LONG & SHORT
  //   int256 totalFundingFeeLong = 0;
  //   int256 totalFundingFeeShort = 0;
  //   {
  //     uint256 _len = _configStorage.getMarketConfigsLength();
  //     for (uint256 i = 0; i < _len; ) {
  //       PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(i);

  //       if (_globalMarket.longOpenInterest > 0 || _globalMarket.shortOpenInterest > 0) {
  //         totalFundingFeeLong += _globalMarket.accumFundingLong;
  //         totalFundingFeeShort += _globalMarket.accumFundingShort;
  //       }

  //       unchecked {
  //         i++;
  //       }
  //     }
  //   }

  //   // Focus on positive funding accrued side
  //   uint256 totalFundingFee = totalFundingFeeLong > totalFundingFeeShort
  //     ? uint(totalFundingFeeLong)
  //     : uint(totalFundingFeeShort);

  //   // Calculate value of current FundingFee amounts
  //   uint256 fundingFeeValue;
  //   address[] memory collateralTokens = _configStorage.getCollateralTokens();
  //   uint256 collateralTokensLength = collateralTokens.length;

  //   {
  //     for (uint256 i; i < collateralTokensLength; ) {
  //       bytes32 tokenAssetId = _configStorage.tokenAssetIds(collateralTokens[i]);
  //       uint8 tokenDecimal = _configStorage.getAssetTokenDecimal(collateralTokens[i]);
  //       (uint256 tokenPrice, ) = _oracle.getLatestPrice(tokenAssetId, false);

  //       uint256 fundingFeeAmount = _vaultStorage.fundingFeeReserve(collateralTokens[i]);
  //       if (fundingFeeAmount > 0) {
  //         fundingFeeValue += (fundingFeeAmount * tokenPrice) / (10 ** tokenDecimal);
  //       }

  //       unchecked {
  //         ++i;
  //       }
  //     }
  //   }

  //   // If totalFundingFee > fundingFeeValue means protocol has exceed balance of fee reserved for paying to traders
  //   // Funding fee surplus = totalFundingFee - fundingFeeValue
  //   if (totalFundingFee < fundingFeeValue) revert ICrossMarginHandler_NoFundingFeeSurplus();
  //   uint256 fundingFeeSurplusValue = totalFundingFee - fundingFeeValue;
  //   uint256 fundingFeeSurplusAmount;

  //   // Looping through fundingFee to transfer surplus amount to PLP
  //   {
  //     for (uint256 i; i < collateralTokensLength; ) {
  //       bytes32 tokenAssetId = _configStorage.tokenAssetIds(collateralTokens[i]);
  //       uint8 tokenDecimal = _configStorage.getAssetTokenDecimal(collateralTokens[i]);
  //       (uint256 tokenPrice, ) = _oracle.getLatestPrice(tokenAssetId, false);

  //       uint256 fundingFeeAmount = _vaultStorage.fundingFeeReserve(collateralTokens[i]);
  //       uint256 fundingFeeValue = (fundingFeeAmount * tokenPrice) / (10 ** tokenDecimal);

  //       //@todo - still implementing
  //       if (fundingFeeValue > fundingFeeSurplusValue) {
  //         fundingFeeSurplusAmount = (fundingFeeSurplusValue * RATE_PRECISION) / tokenPrice;
  //       }

  //       unchecked {
  //         ++i;
  //       }
  //     }
  //   }
  // }

  function _getRepayAmount(
    ConfigStorage _configStorage,
    uint256 _traderBalance,
    uint256 _feeValueE30,
    address _token,
    uint256 _tokenPrice
  ) internal view returns (uint256 _repayAmount, uint256 _repayValueE30) {
    uint8 _tokenDecimal = _configStorage.getAssetTokenDecimal(_token);
    uint256 _feeAmount = (_feeValueE30 * (10 ** _tokenDecimal)) / _tokenPrice;

    if (_traderBalance > _feeAmount) {
      // _traderBalance can cover the rest of the fee
      return (_feeAmount, _feeValueE30);
    } else {
      // _traderBalance cannot cover the rest of the fee, just take the amount the trader have
      uint256 _traderBalanceValue = (_traderBalance * _tokenPrice) / (10 ** _tokenDecimal);
      return (_traderBalance, _traderBalanceValue);
    }
  }

  receive() external payable {
    // @dev Cannot enable this check due to Solidity Fallback Function Gas Limit introduced in 0.8.17.
    // ref - https://stackoverflow.com/questions/74930609/solidity-fallback-function-gas-limit
    // require(msg.sender == ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth());
  }
}
