// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MockErc20 } from "@hmx/tokens/MockErc20.sol";

contract TestTokenMinter {
  address public testToken;

  constructor(address _testToken) {
    testToken = _testToken;
  }

  function mintTestToken() external {
    MockErc20(testToken).mint(msg.sender, 1000 * 1e6);
  }
}
