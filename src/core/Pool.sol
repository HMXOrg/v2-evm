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
  mapping(address => uint256) public totalOf;
  mapping(address => uint256) public liquidityOf;

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
  /// @param isUseMaxPrice Whether to use the max price of the price feed.
  /// @param isStrict Whether to revert if the price is stale.
  /// @return The total AUM of the pool in USD, 30 decimals.
  function getAumE30(bool isUseMaxPrice, bool isStrict)
    public
    view
    returns (uint256)
  {
    address whichUnderlying =
      poolConfig.getNextUnderlyingOf(ITERABLE_ADDRESS_LIST_START);
    uint256 aum = 0;

    // Find out underlying value in USD.
    while (whichUnderlying != ITERABLE_ADDRESS_LIST_END) {
      // Get price and last update time.
      (uint256 price,) = oracleMiddleware.getLatestPrice(
        whichUnderlying.toBytes32(), isUseMaxPrice, isStrict
      );

      // Get underlying's liquidity.
      uint256 underlyingBalance = liquidityOf[whichUnderlying];
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

  /// @notice Get the total AUM of the pool in USD.
  /// @dev This uses to calculate the total value of the pool.
  /// @param isUseMaxPrice Whether to use the max price of the price feed.
  /// @param isStrict Whether to revert if the price is stale.
  /// @return The total AUM of the pool in USD, 18 decimals.
  function getAumE18(bool isUseMaxPrice, bool isStrict)
    public
    view
    returns (uint256)
  {
    return getAumE30(isUseMaxPrice, isStrict) * 1e18 / 1e30;
  }

  // function _calcFee(
  //   address token,
  //   uint256 price,
  //   uint256 baseFeeBps,
  //   uint256 maxFeeDeltaBps,
  //   bool isLong
  // ) internal view returns (uint256) {
  //   if (!poolConfig.isDynamicFeeOn()) return baseFeeBps;
  // }

  /// @notice Calculate the amount of liquidity to mint for the given token and amountIn.
  /// @param token The token to add liquidity.
  /// @param amountIn The amount of token to add liquidity.
  function _calcAddLiquidity(address token, uint256 amountIn)
    internal
    view
    returns (uint256 liquidity)
  {
    (uint256 price,) =
      oracleMiddleware.getLatestPrice(token.toBytes32(), false, true);
    // uint8 decimals = poolConfig.getDecimalsOf(token);
    uint256 amountInUSD = amountIn * price / ORACLE_PRICE_PRECISION;
    // amountInUSD = amountInUSD.convertDecimals(decimals, ORACLE_PRICE_DECIMALS);
    if (amountInUSD == 0) revert Pool_InsufficientAmountIn();

    /// TODO: add mint fee calculation around here.

    uint256 poolAum = getAumE18(true, true);
    uint256 plpTotalSupply = plpv2.totalSupply();

    if (plpTotalSupply == 0) liquidity = amountInUSD;
    else liquidity = (amountInUSD * plpTotalSupply) / poolAum;
  }

  /// @notice Add liquidity to the pool.
  /// @param token The token to add liquidity.
  /// @param to The address to mint liquidity to.
  function addLiquidity(ERC20 token, address to)
    external
    returns (uint256 liquidity)
  {
    // check if token is acceptable
    if (!poolConfig.isAcceptUnderlying(address(token))) revert Pool_BadArgs();

    // transfer token from msg.sender to this contract
    uint256 amountIn = _doTransferIn(token);

    // calculate liquidity
    liquidity = _calcAddLiquidity(address(token), amountIn);

    // effects
    // increase underlying balance
    liquidityOf[address(token)] += amountIn;

    // interaction
    // mint PLPv2 to "to" address
    plpv2.mint(to, liquidity);
  }

  /// @notice Internal function to recognized balance and return the amount actually transferred in.
  /// @param token The ERC20 token to transfer in.
  function _doTransferIn(ERC20 token) internal returns (uint256) {
    // get recognized balance.
    uint256 balanceBefore = totalOf[address(token)];
    // get actual balance.
    uint256 balanceAfter = token.balanceOf(address(this));

    // update recognized balance.
    totalOf[address(token)] = balanceAfter;

    return balanceAfter - balanceBefore;
  }
}
