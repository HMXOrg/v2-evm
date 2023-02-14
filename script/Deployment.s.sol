// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { OracleMiddleware } from "../src/oracle/OracleMiddleware.sol";
import { PythAdapter } from "../src/oracle/PythAdapter.sol";

abstract contract Deployment {
  struct DeployReturnVars {
    OracleMiddleware oracleMiddleware;
    PythAdapter pythAdapter;
  }

  struct DeployLocalVars {
    IPyth pyth;
    uint64 defaultOracleStaleTime;
  }

  function deploy(
    DeployLocalVars memory localVars
  ) internal returns (DeployReturnVars memory) {
    DeployReturnVars memory vars;

    vars.pythAdapter = new PythAdapter(localVars.pyth);
    vars.oracleMiddleware = new OracleMiddleware(
      localVars.pyth,
      vars.pythAdapter
    );

    return vars;
  }
}
