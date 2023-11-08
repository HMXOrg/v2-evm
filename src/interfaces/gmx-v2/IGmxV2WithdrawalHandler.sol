// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

interface IGmxV2WithdrawalHandler {
  function oracle() external view returns (address);

  function executeWithdrawal(bytes32 key, IGmxV2Oracle.SetPricesParams calldata oracleParams) external;
}
