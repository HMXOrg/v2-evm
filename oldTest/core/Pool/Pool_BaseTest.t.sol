// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseTest } from "../../base/BaseTest.sol";
import { PythAdapter } from "../../../oldSrc/oracles/PythAdapter.sol";
import { OracleMiddleware } from "../../../oldSrc/oracles/OracleMiddleware.sol";
import { PoolConfig } from "../../../oldSrc/core/PoolConfig.sol";
import { Pool } from "../../../oldSrc/core/Pool.sol";
import { PLPv2 } from "../../../oldSrc/core/PLPv2.sol";
import { AddressUtils } from "../../../oldSrc/libraries/AddressUtils.sol";

abstract contract Pool_BaseTest is BaseTest {
  using AddressUtils for address;

  PythAdapter pythAdapter;
  OracleMiddleware oracleMiddleware;
  PoolConfig poolConfig;
  Pool pool;
  PLPv2 plpv2;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();

    poolConfig = deployed.poolConfig;
    pool = deployed.pool;
    plpv2 = deployed.plpv2;

    // Setup default underlyings
    (address[] memory underlyings, PoolConfig.UnderlyingConfig[] memory configs) = setupDefaultUnderlying();
    poolConfig.addOrUpdateUnderlying(underlyings, configs);

    // Setup pyth adapter
    pythAdapter = deployed.pythAdapter;
    pythAdapter.setPythPriceId(address(weth).toBytes32(), wethPriceId);
    pythAdapter.setPythPriceId(address(wbtc).toBytes32(), wbtcPriceId);
    pythAdapter.setPythPriceId(address(dai).toBytes32(), daiPriceId);
    pythAdapter.setPythPriceId(address(usdc).toBytes32(), usdcPriceId);
  }
}
