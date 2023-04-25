// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

interface IBridgeStrategy {
  function execute(
    address caller,
    uint256 destinationChainId,
    address tokenRecipient,
    uint256 amount,
    bytes memory payload
  ) external payable;
}
