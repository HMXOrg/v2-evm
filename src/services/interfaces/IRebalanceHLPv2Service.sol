// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IRebalanceHLPv2Service {
  error IRebalanceHLPv2Service_AmountIsZero();
  error IRebalanceHLPv2Service_BadPullAmount();
  error IRebalanceHLPv2Service_KeyNotFound();
  error IRebalanceHLPv2Service_Unauthorized();
  error IRebalanceHLPv2Service_ZeroGmReceived();

  struct DepositParams {
    address market;
    address longToken;
    uint256 longTokenAmount;
    address shortToken;
    uint256 shortTokenAmount;
    uint256 minMarketTokens;
    uint256 gasLimit;
  }

  struct WithdrawalParams {
    address market;
    uint256 amount;
    uint256 minLongTokenAmount;
    uint256 minShortTokenAmount;
    uint256 gasLimit;
  }

  function createDepositOrders(
    DepositParams[] calldata _depositParams,
    uint256 _executionFee
  ) external returns (bytes32[] memory _gmxOrderKeys);

  function createWithdrawalOrders(
    WithdrawalParams[] calldata _withdrawalParams,
    uint256 _executionFee
  ) external returns (bytes32[] memory _gmxOrderKeys);
}
