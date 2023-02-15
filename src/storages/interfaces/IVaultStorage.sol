// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVaultStorage {
  // GETTER
  function traderBalances(
    address _trader,
    address _token
  ) external view returns (uint amount);

  function getTraderTokens(
    address _trader
  ) external view returns (address[] memory);

  function fees(address _token) external view returns (uint256);

  function plpLiquidityUSDE30(address _token) external view returns (uint256);

  function plpTotalLiquidityUSDE30() external returns (uint256);

  function plpLiquidity(address _token) external view returns (uint256);

  // SETTER
  function addFee(address _token, uint256 _amount) external;

  function addPLPLiquidityUSDE30(address _token, uint256 amount) external;

  function addPLPTotalLiquidityUSDE30(uint256 _liquidity) external;

  function addPLPLiquidity(address _token, uint256 _amount) external;
}
