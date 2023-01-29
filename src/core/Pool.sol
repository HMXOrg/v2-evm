// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from
  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";
import {PLPv2} from "./PLPv2.sol";
import {PoolConfig} from "./PoolConfig.sol";

contract Pool {
  // using libs for type
  using SafeERC20 for ERC20;

  // erros
  error Pool_BadArgs();

  // state variables
  IPyth public pyth;
  PLPv2 public plpv2;
  PoolConfig public poolConfig;

  constructor(IPyth _pyth, PLPv2 _plpv2, PoolConfig _poolConfig) {
    pyth = _pyth;
    plpv2 = _plpv2;
    poolConfig = _poolConfig;
  }

  function addLiquidity(
    ERC20 token,
    uint256 amountIn,
    uint256 minLiquidity,
    address to,
    bytes[] calldata pythUpdateData
  ) external {
    // check if token is acceptable
    if (!poolConfig.isAcceptUnderlying(address(token))) revert Pool_BadArgs();

    // update prices
    uint256 pythUpdateFee = pyth.getUpdateFee(pythUpdateData);
    pyth.updatePriceFeeds{value: pythUpdateFee}(pythUpdateData);

    // transfer token from msg.sender to this contract
    token.safeTransferFrom(msg.sender, address(this), amountIn);

    // calculate liquidity

    plpv2.mint(to, minLiquidity);
  }
}
