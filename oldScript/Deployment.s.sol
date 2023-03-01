// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolConfig } from "../src/core/PoolConfig.sol";
import { PLPv2 } from "../src/core/PLPv2.sol";
import { Pool } from "../src/core/Pool.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { OracleMiddleware } from "../src/oracles/OracleMiddleware.sol";
import { ChainlinkAdapter } from "../src/oracles/ChainlinkAdapter.sol";
import { PythAdapter } from "../src/oracles/PythAdapter.sol";

abstract contract Deployment {
  struct DeployReturnVars {
    OracleMiddleware oracleMiddleware;
    ChainlinkAdapter chainlinkAdapter;
    PythAdapter pythAdapter;
    PoolConfig poolConfig;
    PLPv2 plpv2;
    Pool pool;
  }

  struct DeployLocalVars {
    IPyth pyth;
    uint64 defaultOracleStaleTime;
  }

  function deploy(DeployLocalVars memory localVars) internal returns (DeployReturnVars memory) {
    DeployReturnVars memory vars;

    vars.chainlinkAdapter = new ChainlinkAdapter(3);
    vars.pythAdapter = new PythAdapter(localVars.pyth);
    vars.oracleMiddleware = new OracleMiddleware(localVars.pyth, vars.chainlinkAdapter, vars.pythAdapter);
    vars.poolConfig = new PoolConfig();
    vars.plpv2 = new PLPv2();
    vars.pool = new Pool(localVars.pyth, vars.oracleMiddleware, vars.plpv2, vars.poolConfig);

    vars.plpv2.setMinter(address(vars.pool), true);

    return vars;
  }
}
