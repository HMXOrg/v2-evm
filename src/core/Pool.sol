// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from
  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AddressUtils} from "../libraries/AddressUtils.sol";
import {DecimalsUtils} from "../libraries/DecimalsUtils.sol";
import {TransferEthUtils} from "../libraries/TransferEthUtils.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";
import {PLPv2} from "./PLPv2.sol";
import {PoolConfig} from "./PoolConfig.sol";
import {OracleMiddleware} from "../oracle/OracleMiddleware.sol";
import {Constants} from "../base/Constants.sol";

contract Pool is Constants {
  // using libs for type
  using SafeERC20 for ERC20;
  using AddressUtils for address;
  using TransferEthUtils for address;
  using DecimalsUtils for uint256;

  // erros
  error Pool_BadArgs();
  error Pool_InsufficientAmountIn();
  error Pool_InsufficientMsgValue();
  error Pool_PriceStale();
  error Pool_Slippage();

  // configs
  IPyth public pyth;
  OracleMiddleware public oracleMiddleware;
  PLPv2 public plpv2;
  PoolConfig public poolConfig;

  // states
  mapping(address => uint256) public underlyingBalances;

  constructor(
    IPyth _pyth,
    OracleMiddleware _oracleMiddleware,
    PLPv2 _plpv2,
    PoolConfig _poolConfig
  ) {
    pyth = _pyth;
    oracleMiddleware = _oracleMiddleware;
    plpv2 = _plpv2;
    poolConfig = _poolConfig;
  }

  /// @notice Get the total AUM of the pool in USD with 30 decimals.
  /// @dev This uses to calculate the total value of the pool.
  function getAum() public view returns (uint256) {
    address whichUnderlying =
      poolConfig.getNextUnderlyingOf(ITERABLE_ADDRESS_LIST_START);
    uint256 aum = 0;

    // Find out underlying value in USD.
    while (whichUnderlying != ITERABLE_ADDRESS_LIST_END) {
      // NOTE: Might be better to consolidate price stale action.
      // For example, combined ADD and REMOVE liquidity.

      // Get price and last update time.
      (uint256 price,) =
        oracleMiddleware.getLatestPrice(whichUnderlying.toBytes32());

      // Get underlying balance.
      uint256 underlyingBalance = underlyingBalances[whichUnderlying];
      // Get underlying decimals.
      uint256 decimals = poolConfig.getDecimalsOf(whichUnderlying);

      // Calculate underlying value in USD and add to AUM.
      aum += (underlyingBalance * price) / 10 ** decimals;

      // Loop through the next underlying.
      whichUnderlying = poolConfig.getNextUnderlyingOf(whichUnderlying);
    }

    // TODO: handle product Pool's PnL.

    return aum;
  }

  /// @notice Calculate the amount of liquidity to mint for the given token and amountIn.
  /// @param token The token to add liquidity.
  /// @param amountIn The amount of token to add liquidity.
  function _calcAddLiquidity(address token, uint256 amountIn)
    internal
    view
    returns (uint256 liquidity)
  {
    (uint256 price,) = oracleMiddleware.getLatestPrice(token.toBytes32());
    // uint8 decimals = poolConfig.getDecimalsOf(token);
    uint256 amountInUSD = amountIn * price / ORACLE_PRICE_PRECISION;
    // amountInUSD = amountInUSD.convertDecimals(decimals, ORACLE_PRICE_DECIMALS);
    if (amountInUSD == 0) revert Pool_InsufficientAmountIn();

    /// TODO: add mint fee calculation around here.

    uint256 poolAum = getAum();
    uint256 plpTotalSupply = plpv2.totalSupply();

    if (plpTotalSupply == 0) liquidity = amountInUSD;
    else liquidity = (amountInUSD * plpTotalSupply) / poolAum;
  }

  /// @notice Add liquidity to the pool.
  /// @param token The token to add liquidity.
  /// @param amountIn The amount of token to add liquidity.
  /// @param minLiquidity The minimum liquidity to mint.
  /// @param to The address to mint liquidity to.
  /// @param pythUpdateData The data to update Pyth price feeds.
  function addLiquidity(
    ERC20 token,
    uint256 amountIn,
    uint256 minLiquidity,
    address to,
    bytes[] calldata pythUpdateData
  ) external payable returns (uint256 liquidity) {
    // check if token is acceptable
    if (!poolConfig.isAcceptUnderlying(address(token))) revert Pool_BadArgs();

    // update prices
    uint256 pythUpdateFee = pyth.getUpdateFee(pythUpdateData);
    // check if msg.value is enough to pay pyth update fee
    if (msg.value < pythUpdateFee) revert Pool_InsufficientMsgValue();
    // update price feeds
    pyth.updatePriceFeeds{value: pythUpdateFee}(pythUpdateData);

    // transfer token from msg.sender to this contract
    underlyingBalances[address(token)] += _doTransferIn(token, amountIn);

    // calculate liquidity
    liquidity = _calcAddLiquidity(address(token), amountIn);

    // check min liquidity
    if (liquidity < minLiquidity) revert Pool_Slippage();

    // interaction
    // mint PLPv2 to "to" address
    plpv2.mint(to, liquidity);
    // refunds the over paid balance to msg.sender.
    if (msg.value > pythUpdateFee) {
      msg.sender.safeTransferETH(msg.value - pythUpdateFee);
    }
  }

  /// @notice Internal function to perform ERC20 transfer in and return the amount actually transferred in.
  /// @param token The ERC20 token to transfer in.
  /// @param amountInCall The amount of token uses in transferFrom call.
  function _doTransferIn(ERC20 token, uint256 amountInCall)
    internal
    returns (uint256)
  {
    uint256 balanceBefore = token.balanceOf(address(this));
    token.safeTransferFrom(msg.sender, address(this), amountInCall);
    uint256 balanceAfter = token.balanceOf(address(this));
    return balanceAfter - balanceBefore;
  }
}
