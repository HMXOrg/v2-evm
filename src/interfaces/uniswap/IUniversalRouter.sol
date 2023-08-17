// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IUniversalRouter {
  struct SwapCallbackData {
    bytes path;
    address payer;
  }

  function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}
