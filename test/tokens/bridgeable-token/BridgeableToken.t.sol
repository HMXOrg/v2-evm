// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../../base/BaseTest.sol";
import { HMX } from "@hmx/tokens/HMX.sol";
import { LZBridgeStrategy } from "@hmx/tokens/bridge-strategies/LZBridgeStrategy.sol";
import { LZBridgeReceiver } from "@hmx/tokens/bridge-receiver/LZBridgeReceiver.sol";
import { MockLZEndpoint } from "../../mocks/MockLZEndpoint.sol";

contract BridgeableToken is BaseTest {
  HMX internal hmxOnETH;
  HMX internal hmxOnPolygon;
  LZBridgeStrategy internal bridgeStratOnETH;
  LZBridgeReceiver internal bridgeReceiverOnETH;
  LZBridgeStrategy internal bridgeStratOnPolygon;
  LZBridgeReceiver internal bridgeReceiverOnPolygon;

  MockLZEndpoint internal lzEndpoint;

  uint256 internal constant ETHEREUM_CHAIN_ID = 1;
  uint256 internal constant POLYGON_CHAIN_ID = 156;

  function setUp() public virtual {
    hmxOnETH = new HMX(false);
    hmxOnPolygon = new HMX(true);

    lzEndpoint = new MockLZEndpoint();

    bridgeStratOnETH = new LZBridgeStrategy(address(lzEndpoint));
    bridgeReceiverOnETH = new LZBridgeReceiver(address(lzEndpoint), address(hmxOnETH));

    bridgeStratOnPolygon = new LZBridgeStrategy(address(lzEndpoint));
    bridgeReceiverOnPolygon = new LZBridgeReceiver(address(lzEndpoint), address(hmxOnPolygon));

    uint256[] memory destChainIds = new uint256[](1);
    destChainIds[0] = POLYGON_CHAIN_ID;
    address[] memory destContracts = new address[](1);
    destContracts[0] = address(bridgeReceiverOnPolygon);
    bridgeStratOnETH.setDestinationTokenContracts(destChainIds, destContracts);
    destChainIds[0] = ETHEREUM_CHAIN_ID;
    destContracts[0] = address(bridgeReceiverOnETH);
    bridgeStratOnPolygon.setDestinationTokenContracts(destChainIds, destContracts);

    uint16[] memory srcChainIds = new uint16[](1);
    srcChainIds[0] = uint16(POLYGON_CHAIN_ID);
    bytes[] memory remoteAddresses = new bytes[](1);
    remoteAddresses[0] = abi.encode(address(bridgeStratOnPolygon));
    bridgeReceiverOnETH.setTrustedRemotes(srcChainIds, remoteAddresses);
    srcChainIds[0] = uint16(ETHEREUM_CHAIN_ID);
    remoteAddresses[0] = abi.encode(address(bridgeStratOnETH));
    bridgeReceiverOnPolygon.setTrustedRemotes(srcChainIds, remoteAddresses);

    hmxOnETH.setMinter(address(this), true);
    hmxOnETH.setBridge(address(bridgeReceiverOnETH), true);
    hmxOnPolygon.setBridge(address(bridgeReceiverOnPolygon), true);

    hmxOnETH.setBridgeStrategy(address(bridgeStratOnETH), true);
    hmxOnPolygon.setBridgeStrategy(address(bridgeStratOnPolygon), true);
  }

  function testCorrectness_bridgeTokenFromETHToPolygon() external {
    hmxOnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(uint16(ETHEREUM_CHAIN_ID), abi.encode(bridgeStratOnETH));

    vm.startPrank(ALICE);
    hmxOnETH.bridgeToken(POLYGON_CHAIN_ID, BOB, 1 ether, address(bridgeStratOnETH), abi.encode(0));
    vm.stopPrank();

    assertEq(hmxOnPolygon.balanceOf(BOB), 1 ether, "Bob should receive the bridged token.");
    assertEq(hmxOnETH.balanceOf(ALICE), 0 ether, "Alice should not have any HMX left, as she bridged all her token.");
    assertEq(hmxOnETH.balanceOf(address(hmxOnETH)), 1 ether, "Bridged HMX should be locked on Ethereum.");
  }

  function testCorrectness_bridgeTokenFromPolygonBackToETH() external {
    hmxOnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(uint16(ETHEREUM_CHAIN_ID), abi.encode(bridgeStratOnETH));

    vm.startPrank(ALICE);
    hmxOnETH.bridgeToken(POLYGON_CHAIN_ID, BOB, 1 ether, address(bridgeStratOnETH), abi.encode(0));
    vm.stopPrank();

    assertEq(hmxOnPolygon.balanceOf(BOB), 1 ether);

    lzEndpoint.setSource(uint16(POLYGON_CHAIN_ID), abi.encode(bridgeStratOnPolygon));

    vm.startPrank(BOB);
    hmxOnPolygon.bridgeToken(ETHEREUM_CHAIN_ID, ALICE, 0.5 ether, address(bridgeStratOnPolygon), abi.encode(0));
    vm.stopPrank();

    assertEq(hmxOnETH.balanceOf(ALICE), 0.5 ether, "Alice should receive the bridged token.");
    assertEq(
      hmxOnPolygon.balanceOf(BOB),
      0.5 ether,
      "Bob should have half of his token left, as he bridge the other half to Alice."
    );
    assertEq(hmxOnPolygon.balanceOf(address(hmxOnPolygon)), 0 ether, "HMX should be burnt on Polygon.");
    assertEq(
      hmxOnETH.balanceOf(address(hmxOnETH)),
      0.5 ether,
      "HMX should be transferred from the locked token on Ethereum, not newly minted."
    );
    assertEq(hmxOnETH.totalSupply(), 1 ether, "Total supply on ETH should stay the same.");
  }

  function testRevert_BadStrategy() external {
    hmxOnETH.mint(ALICE, 1 ether);
    vm.startPrank(ALICE);

    vm.expectRevert(abi.encodeWithSignature("BaseBridgeableToken_BadStrategy()"));
    hmxOnETH.bridgeToken(POLYGON_CHAIN_ID, BOB, 1 ether, address(1), abi.encode(0));
    vm.stopPrank();
  }

  function testRevert_UnknownChainId() external {
    hmxOnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(uint16(ETHEREUM_CHAIN_ID), abi.encode(bridgeStratOnETH));

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("LZBridgeStrategy_UnknownChainId()"));
    hmxOnETH.bridgeToken(0, BOB, 1 ether, address(bridgeStratOnETH), abi.encode(0));
    vm.stopPrank();
  }

  function testRevert_InvalidSource() external {
    hmxOnETH.mint(ALICE, 1 ether);

    lzEndpoint.setSource(uint16(ETHEREUM_CHAIN_ID), abi.encode(bridgeStratOnETH));

    uint16[] memory srcChainIds = new uint16[](1);
    bytes[] memory remoteAddresses = new bytes[](1);
    srcChainIds[0] = uint16(ETHEREUM_CHAIN_ID);
    remoteAddresses[0] = abi.encode(address(0));
    bridgeReceiverOnPolygon.setTrustedRemotes(srcChainIds, remoteAddresses);

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("LZBridgeReceiver_InvalidSource()"));
    hmxOnETH.bridgeToken(POLYGON_CHAIN_ID, BOB, 1 ether, address(bridgeStratOnETH), abi.encode(0));
    vm.stopPrank();
  }

  function testCorrectness_exploitOnPolygon() external {
    hmxOnETH.mint(ALICE, 1000 ether);

    lzEndpoint.setSource(uint16(ETHEREUM_CHAIN_ID), abi.encode(bridgeStratOnETH));

    vm.startPrank(ALICE);
    hmxOnETH.bridgeToken(POLYGON_CHAIN_ID, BOB, 1 ether, address(bridgeStratOnETH), abi.encode(0));
    vm.stopPrank();

    assertEq(hmxOnPolygon.balanceOf(BOB), 1 ether);

    lzEndpoint.setSource(uint16(POLYGON_CHAIN_ID), abi.encode(bridgeStratOnPolygon));

    // Hacker mint the full supply
    hmxOnPolygon.setMinter(address(this), true);
    hmxOnPolygon.mint(BOB, 999_999 ether);

    vm.startPrank(BOB);
    hmxOnPolygon.bridgeToken(ETHEREUM_CHAIN_ID, ALICE, 1_000_000 ether, address(bridgeStratOnPolygon), abi.encode(0));
    vm.stopPrank();

    assertEq(hmxOnETH.totalSupply(), 1000 ether);
  }
}
