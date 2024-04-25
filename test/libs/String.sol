// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.
pragma solidity 0.8.18;

library String {
  function isEmpty(string memory str) internal pure returns (bool) {
    bytes memory strBytes = bytes(str);
    return strBytes.length == 0;
  }
}
