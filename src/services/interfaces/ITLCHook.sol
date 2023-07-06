// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITLCHook {
    function marketWeights(uint256 marketIndex) external view returns(uint256);

    function setMarketWeight(uint256 marketIndex, uint256 weight) external;
}