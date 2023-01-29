// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from
  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PLPv2} from "./PLPv2.sol";
import {PoolConfig} from "./PoolConfig.sol";

contract Pool {
  // using libs for type
  using SafeERC20 for ERC20;

  // erros
  error Pool_BadArgs();

  // state variables
  PLPv2 public plpv2;
  PoolConfig public poolConfig;

  constructor(PLPv2 _plpv2, PoolConfig _poolConfig) {
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

    // transfer token from msg.sender to this contract
    token.safeTransferFrom(msg.sender, address(this), amountIn);

    // mint liquidity token to msg.sender
    plpv2.mint(to, minLiquidity);
  }
}
