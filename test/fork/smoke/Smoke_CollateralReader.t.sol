// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CollateralReader } from "@hmx/readers/CollateralReader.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract Smoke_CollateralReader is Test {
  function test() public virtual {
    vm.createSelectFork(vm.envString("BLAST_SEPOLIA_RPC"));
    CollateralReader reader = new CollateralReader(
      IVaultStorage(0x3f78cEc168AdF9242a3d2F04A0ab1E312c26b3Ec),
      IConfigStorage(0x4Dc3c929DDa7451012F408d1f376221621dD2a56)
    );
    address[] memory ybTokens = new address[](2);
    ybTokens[0] = 0x628eF5ADFf7da4980CeA33E05568d22772E87EB8;
    ybTokens[1] = 0x073315910A2B432F2f9482bCEAFe34420718c7Cc;
    bool[] memory isYbs = new bool[](2);
    isYbs[0] = true;
    isYbs[1] = true;
    reader.setIsYbToken(ybTokens, isYbs);
    reader.getCollaterals(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a, 0);
  }
}
