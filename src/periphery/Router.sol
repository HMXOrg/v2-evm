// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from
  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {WrappedNativeInterface} from "../interfaces/WrappedNativeInterface.sol";
import {TransferEthUtils} from "../libraries/TransferEthUtils.sol";
import {Pool} from "../core/Pool.sol";

contract Router {
  // dependencies
  using SafeERC20 for ERC20;
  using TransferEthUtils for address;

  // errors
  error Router_InsufficientMsgValue();
  error Router_Slippage();

  IPyth public pyth;
  WrappedNativeInterface public wNative;
  Pool public pool;

  constructor(IPyth _pyth, WrappedNativeInterface _wNative, Pool _pool) {
    pyth = _pyth;
    wNative = _wNative;
    pool = _pool;
  }

  function _updatePythData(bytes[] memory pythUpdateData)
    internal
    returns (uint256 refundValue)
  {
    // update prices
    uint256 pythUpdateFee = pyth.getUpdateFee(pythUpdateData);
    // check if msg.value is enough to pay pyth update fee
    if (msg.value < pythUpdateFee) revert Router_InsufficientMsgValue();
    // update price feeds
    pyth.updatePriceFeeds{value: pythUpdateFee}(pythUpdateData);
    // return refund value
    return msg.value - pythUpdateFee;
  }

  /// @notice Add liquidity to the pool.
  /// @param token The token to add liquidity with.
  /// @param amount The amount of token to add.
  /// @param to The address to send the liquidity tokens to.
  /// @param minLiquidity The minimum liquidity to receive.
  /// @param pythUpdateData The data to update pyth price feeds.
  /// @return liquidity The amount of liquidity tokens minted.
  function addLiquidity(
    ERC20 token,
    uint256 amount,
    address to,
    uint256 minLiquidity,
    bytes[] memory pythUpdateData
  ) external payable returns (uint256) {
    // update pyth data
    uint256 toRefund = _updatePythData(pythUpdateData);

    // transfer token from msg.sender to pool.
    token.safeTransferFrom(msg.sender, address(pool), amount);

    uint256 liquidity = pool.addLiquidity(token, to);
    // check min liquidity
    if (liquidity < minLiquidity) revert Router_Slippage();

    // TODO: Auto stake PLP to earn yields around here.

    // refund if any extra value is sent
    if (toRefund > 0) {
      msg.sender.safeTransferETH(toRefund);
    }

    return liquidity;
  }
}
