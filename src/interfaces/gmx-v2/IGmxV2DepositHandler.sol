// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

interface IGmxV2DepositHandler {
  function oracle() external view returns (address);

  function executeDeposit(bytes32 key, IGmxV2Oracle.SetPricesParams calldata oracleParams) external;
}
