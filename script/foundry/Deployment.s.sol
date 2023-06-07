// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { OracleMiddleware } from "../src/oracles/OracleMiddleware.sol";
import { PythAdapter } from "../src/oracles/PythAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";

abstract contract Deployment {
  struct DeployReturnVars {
    OracleMiddleware oracleMiddleware;
  }

  function deploy() internal returns (DeployReturnVars memory) {
    DeployReturnVars memory vars;

    vars.oracleMiddleware = new OracleMiddleware();

    return vars;
  }
}
