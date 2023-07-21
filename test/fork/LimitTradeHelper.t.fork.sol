// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

import { console } from "forge-std/console.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { console2 } from "forge-std/console2.sol";
import { LimitTradeHelper } from "@hmx/helpers/LimitTradeHelper.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LimitTradeHelper_fork is TestBase, StdAssertions, StdCheatsSafe {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));
    vm.rollFork(113024617);
  }

  function testCorrectness_closeLargestPosition() external {
    vm.warp(1689831128);
    LimitTradeHandler limitTradeHandler = LimitTradeHandler(payable(0xeE116128b9AAAdBcd1f7C18608C5114f594cf5D6));
    PerpStorage perpStorage = PerpStorage(payable(0x97e94BdA44a2Df784Ab6535aaE2D62EFC6D2e303));
    address positionOwner = 0xdDd53521C1685549708103d122b2540FfB8b4428;
    bytes32 positionId = HMXLib.getPositionId(positionOwner, 1);

    PerpStorage.Position memory positionBefore = perpStorage.getPositionById(positionId);
    assertGt(HMXLib.abs(positionBefore.positionSizeE30), 0);

    LimitTradeHandler newLimitTradeHandlerImp = new LimitTradeHandler();
    ProxyAdmin proxyAdmin = ProxyAdmin(0x2E7983f9A1D08c57989eEA20adC9242321dA6589);

    vm.startPrank(proxyAdmin.owner());
    proxyAdmin.upgrade(
      TransparentUpgradeableProxy(payable(0xeE116128b9AAAdBcd1f7C18608C5114f594cf5D6)),
      address(newLimitTradeHandlerImp)
    );
    vm.stopPrank();

    vm.startPrank(limitTradeHandler.owner());
    LimitTradeHelper limitTradeHelper = new LimitTradeHelper(
      0xF4F7123fFe42c4C90A4bCDD2317D397E0B7d7cc0,
      0x97e94BdA44a2Df784Ab6535aaE2D62EFC6D2e303
    );
    limitTradeHandler.setLimitTradeHelper(address(limitTradeHelper));
    limitTradeHelper.setPositionSizeLimit(0, 500_000 * 1e30, 300_000 * 1e30);
    vm.stopPrank();

    vm.prank(positionOwner);
    limitTradeHandler.createOrder{ value: 0.0003 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 270000000000000000000000000000000000,
      _triggerPrice: 0,
      _acceptablePrice: 270000000000000000000000000000000000,
      _triggerAboveThreshold: true,
      _executionFee: 0.0003 ether,
      _reduceOnly: true,
      _tpToken: 0x0000000000000000000000000000000000000000
    });

    address[] memory _accounts = new address[](1);
    _accounts[0] = positionOwner;
    uint8[] memory _subAccountIds = new uint8[](1);
    _subAccountIds[0] = 0;
    uint256[] memory _orderIndexes = new uint256[](1);
    _orderIndexes[0] = 33;
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = bytes32(0x0126f60192c4ffffff000000ffffff00cdf700c0de01289700bf9c00e55c0000);
    _priceData[1] = bytes32(0x00ddd300047d007dfd000086fff118000a0fffd49dfff58bfff31a0009540000);
    _priceData[2] = bytes32(0x00113100b0d600b7ab00bc0400d6770080380000000000000000000000000000);
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0x0086060086040086030086040086020000bc0086060086040008740008710000);
    _publishTimeData[1] = bytes32(0x0008710086040086040086080086040086040086040086060086030086040000);
    _publishTimeData[2] = bytes32(0x0086060086040000000000a20086040086030000000000000000000000000000);
    vm.prank(0x7FDD623c90a0097465170EdD352Be27A9f3ad817);
    limitTradeHandler.executeOrders({
      _accounts: _accounts,
      _subAccountIds: _subAccountIds,
      _orderIndexes: _orderIndexes,
      _feeReceiver: payable(0x7FDD623c90a0097465170EdD352Be27A9f3ad817),
      _priceData: _priceData,
      _publishTimeData: _publishTimeData,
      _minPublishTime: 1689796809,
      _encodedVaas: keccak256("someEncodedVaas")
    });

    PerpStorage.Position memory positionAfter = perpStorage.getPositionById(positionId);
    assertEq(HMXLib.abs(positionAfter.positionSizeE30), 0);
  }
}
