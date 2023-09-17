// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

// Storage
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";

contract Smoke_Base is Test {
  ICalculator public calculator;

  address public constant OWNER = 0x6409ba830719cd0fE27ccB3051DF1b399C90df4a;
  address public constant POS_MANAGER = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E; // set market status;
  address public ALICE;
  address public BOB;

  uint256 internal constant BPS = 10_000;

  address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address internal constant TRADE_SERVICE = 0xcf533D0eEFB072D1BB68e201EAFc5368764daA0E;
  address internal constant EXECUTOR = 0xB75ca1CC0B01B6519Bc879756eC431a95DC37882;
  uint256 private constant _fixedBlock = 130344667;

  function setUp() public virtual {
    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");

    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"));

    // -- UPGRADE -- //
    vm.startPrank(ForkEnv.proxyAdmin.owner());
    Calculator newCalculator = new Calculator();
    ForkEnv.proxyAdmin.upgrade(
      TransparentUpgradeableProxy(payable(0x0FdE910552977041Dc8c7ef652b5a07B40B9e006)),
      address(newCalculator)
    );

    vm.stopPrank();
    // -- LOAD UPGRADE -- //
    calculator = ICalculator(0x0FdE910552977041Dc8c7ef652b5a07B40B9e006);
  }

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  function _setTickPriceZero()
    internal
    pure
    returns (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData)
  {
    int24[] memory tickPrices = new int24[](34);
    uint24[] memory publishTimeDiffs = new uint24[](34);
    for (uint i = 0; i < 34; i++) {
      tickPrices[i] = 0;
      publishTimeDiffs[i] = 0;
    }

    priceUpdateData = ForkEnv.ecoPyth2.buildPriceUpdateData(tickPrices);
    publishTimeUpdateData = ForkEnv.ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
  }

  function _setPriceData(
    uint64 _priceE8
  ) internal view returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34
    assetIds = new bytes32[](len - 1);
    prices = new uint64[](len - 1);
    shouldInverts = new bool[](len - 1);

    for (uint i = 1; i < len; i++) {
      assetIds[i - 1] = pythRes[i];
      prices[i - 1] = _priceE8 * 1e8;
      if (i == 4) {
        shouldInverts[i - 1] = true; // JPY
      } else {
        shouldInverts[i - 1] = false;
      }
    }
  }

  function _buildDataForPrice() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _validateClosedPosition(bytes32 _id) internal {
    IPerpStorage.Position memory _position = ForkEnv.perpStorage.getPositionById(_id);
    // As the position has been closed, the gotten one should be empty stuct
    assertEq(_position.primaryAccount, address(0));
    assertEq(_position.marketIndex, 0);
    assertEq(_position.avgEntryPriceE30, 0);
    assertEq(_position.entryBorrowingRate, 0);
    assertEq(_position.reserveValueE30, 0);
    assertEq(_position.lastIncreaseTimestamp, 0);
    assertEq(_position.positionSizeE30, 0);
    assertEq(_position.realizedPnl, 0);
    assertEq(_position.lastFundingAccrued, 0);
    assertEq(_position.subAccountId, 0);
  }

  function _checkIsUnderMMR(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _limitPriceE30
  ) internal view returns (bool) {
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    IConfigStorage.MarketConfig memory config = ForkEnv.configStorage.getMarketConfigByIndex(_marketIndex);

    int256 _subAccountEquity = calculator.getEquity(_subAccount, _limitPriceE30, config.assetId);
    uint256 _mmr = calculator.getMMR(_subAccount);
    if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) return true;
    return false;
  }
}
