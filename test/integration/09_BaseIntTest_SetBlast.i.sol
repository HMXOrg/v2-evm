// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_SetWhitelist } from "@hmx-test/integration/08_BaseIntTest_SetWhitelist.i.sol";

abstract contract BaseIntTest_SetBlast is BaseIntTest_SetWhitelist {
  constructor() {
    address[] memory _tokens = new address[](2);
    _tokens[0] = address(weth);
    _tokens[1] = address(usdb);

    address[] memory _ybs = new address[](2);
    _ybs[0] = address(ybeth);
    _ybs[1] = address(ybusdb);

    configStorage.setYbTokenOfMany(_tokens, _ybs);
  }
}
