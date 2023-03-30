// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.18;

// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { BaseTest, MockErc20 } from "@hmx-test/base/BaseTest.sol";
// import { Deployer } from "@hmx-test/libs/Deployer.sol";

// import { IVester } from "@hmx/vesting/interfaces/IVester.sol";

// contract Vester_Base is BaseTest {
//   IVester private vester;
//   MockErc20 private hmx;
//   MockErc20 private esHmx;
//   address private constant vestedEsHmxDestinationAddress = address(888);
//   address private constant unusedEsHmxDestinationAddress = address(889);
//   uint256 private constant esHmxTotalSupply = 100 ether;

//   function setUp() public virtual {
//     hmx = new MockErc20("HMX", "HMX", 18);
//     esHmx = new MockErc20("esHMX", "esHMX", 18);
//     vester = Deployer.deployVester(
//       address(this),
//       address(esHmx),
//       address(hmx),
//       vestedEsHmxDestinationAddress,
//       unusedEsHmxDestinationAddress
//     );

//     hmx.mint(address(vester), esHmxTotalSupply);
//     esHmx.mint(address(vesterHandler), esHmxTotalSupply);
//   }
// }
