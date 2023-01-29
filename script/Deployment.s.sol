// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolConfig} from "../src/core/PoolConfig.sol";
import {PLPv2} from "../src/core/PLPv2.sol";
import {Pool} from "../src/core/Pool.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

abstract contract Deployment {
  struct DeployReturnVars {
    PoolConfig poolConfig;
    PLPv2 plpv2;
    Pool pool;
  }

  function deploy(IPyth pyth) internal returns (DeployReturnVars memory) {
    DeployReturnVars memory vars;

    vars.poolConfig = new PoolConfig();
    vars.plpv2 = new PLPv2();
    vars.pool = new Pool(pyth, vars.plpv2, vars.poolConfig);

    vars.plpv2.setMinter(address(vars.pool), true);

    return vars;
  }
}
