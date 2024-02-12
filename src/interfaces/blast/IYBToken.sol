// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IYBToken {
  function depositETH(address _receiver) external payable returns (uint256);

  function deposit(uint256 _assets, address _receiver) external returns (uint256);

  function redeemETH(uint256 _shares, address _receiver, address _owner) external returns (uint256);

  function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256);

  function previewRedeem(uint256 _shares) external returns (uint256);

  function previewWithdraw(uint256 _assets) external returns (uint256);
}
