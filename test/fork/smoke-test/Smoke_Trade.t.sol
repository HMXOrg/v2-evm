// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { PythStructs } from "pyth-sdk-solidity/PythStructs.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";
import { console } from "forge-std/console.sol";
import { console2 } from "forge-std/console2.sol";

contract Smoke_Trade is Smoke_Base {
    using SafeCastUpgradeable for int64;
    uint8 internal SUB_ACCOUNT_NO = 0;
    uint256 internal MARKET_INDEX = 1;
    // eth | jpy | xag | sol | chf
    uint256[] internal ARRAY_MARKET_INDEX = [0, 3, 9, 21, 26];

    IERC20 usdc_e = IERC20(address(ForkEnv.usdc_e));

    function setUp() public virtual override {
        super.setUp();
        ARRAY_MARKET_INDEX[0] = 0;
        ARRAY_MARKET_INDEX[1] = 3;
        ARRAY_MARKET_INDEX[2] = 10;
        ARRAY_MARKET_INDEX[3] = 21;
        ARRAY_MARKET_INDEX[4] = 26;
    }

    function test_open_close_position() external {
        _depositCollateral();
        _createMarketOrder();
    }

    function _depositCollateral() internal {
        uint8 tokenDecimal = usdc_e.decimals();
        deal(address(usdc_e), ALICE, 100 * (10 ** tokenDecimal));
        vm.startPrank(ALICE);
        usdc_e.approve(address(ForkEnv.crossMarginHandler), type(uint256).max);
        ForkEnv.crossMarginHandler.depositCollateral(
            SUB_ACCOUNT_NO,
            address(usdc_e), 
            100 * (10 ** tokenDecimal), 
            false
        );
        vm.stopPrank();
    }

    function _createMarketOrder() internal {
        for (uint i = 0 ; i < ARRAY_MARKET_INDEX.length ; i ++) {

            address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
            deal(ALICE, 1 ether);

            uint256 _orderIndex = ForkEnv.limitTradeHandler.limitOrdersIndex(subAccount);

            vm.prank(ALICE);
            ForkEnv.limitTradeHandler.createOrder{ value: 0.1 ether }({
                _subAccountId: SUB_ACCOUNT_NO,
                _marketIndex: ARRAY_MARKET_INDEX[i],
                _sizeDelta: 1000 * 1e30,
                _triggerPrice: 0,
                _acceptablePrice: type(uint256).max,
                _triggerAboveThreshold: false,
                _executionFee: 0.1 ether,
                _reduceOnly: false,
                _tpToken: address(usdc_e)
            });

            IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
            (
            uint256 _minPublishTime,
            bytes32[] memory _priceUpdateCalldata,
            bytes32[] memory _publishTimeUpdateCalldata
            ) = ecoPythBuilder.build(data);

            address[] memory accounts = new address[](1);
            uint8[] memory subAccountIds = new uint8[](1);
            uint256[] memory orderIndexes = new uint256[](1);
            accounts[0] = ALICE;
            subAccountIds[0] = SUB_ACCOUNT_NO;
            orderIndexes[0] = _orderIndex;

            // Execute Long Increase Order
            vm.prank(0xB75ca1CC0B01B6519Bc879756eC431a95DC37882);
            ForkEnv.limitTradeHandler.executeOrders({
                _accounts: accounts,
                _subAccountIds: subAccountIds,
                _orderIndexes: orderIndexes,
                _feeReceiver: payable(BOB),
                _priceData: _priceUpdateCalldata,
                _publishTimeData: _publishTimeUpdateCalldata,
                _minPublishTime: _minPublishTime,
                _encodedVaas: keccak256("someEncodedVaas"),
                _isRevert: true
            });

            assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), 1, "User must have 1 market position, LONG");
            
            _orderIndex = ForkEnv.limitTradeHandler.limitOrdersIndex(subAccount);

            vm.prank(ALICE);
            ForkEnv.limitTradeHandler.createOrder{ value: 0.1 ether }({
                _subAccountId: SUB_ACCOUNT_NO,
                _marketIndex: ARRAY_MARKET_INDEX[i],
                _sizeDelta: -1000 * 1e30,
                _triggerPrice: 0,
                _acceptablePrice: 0,
                _triggerAboveThreshold: false,
                _executionFee: 0.1 ether,
                _reduceOnly: true,
                _tpToken: address(usdc_e)
            });

            orderIndexes[0] = _orderIndex;

            // Close Long Position
            vm.prank(0xB75ca1CC0B01B6519Bc879756eC431a95DC37882);
            ForkEnv.limitTradeHandler.executeOrders({
                _accounts: accounts,
                _subAccountIds: subAccountIds,
                _orderIndexes: orderIndexes,
                _feeReceiver: payable(BOB),
                _priceData: _priceUpdateCalldata,
                _publishTimeData: _publishTimeUpdateCalldata,
                _minPublishTime: _minPublishTime,
                _encodedVaas: keccak256("someEncodedVaas"),
                _isRevert: true
            });

            assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), 0, "User must have 0 market position after close, LONG");

            _orderIndex = ForkEnv.limitTradeHandler.limitOrdersIndex(subAccount);

            vm.prank(ALICE);
            ForkEnv.limitTradeHandler.createOrder{ value: 0.1 ether }({
                _subAccountId: SUB_ACCOUNT_NO,
                _marketIndex: ARRAY_MARKET_INDEX[i],
                _sizeDelta: -1000 * 1e30,
                _triggerPrice: 0,
                _acceptablePrice: 0,
                _triggerAboveThreshold: false,
                _executionFee: 0.1 ether,
                _reduceOnly: false,
                _tpToken: address(usdc_e)
            });


            orderIndexes[0] = _orderIndex;

            // Open Short Position
            vm.prank(0xB75ca1CC0B01B6519Bc879756eC431a95DC37882);
            ForkEnv.limitTradeHandler.executeOrders({
                _accounts: accounts,
                _subAccountIds: subAccountIds,
                _orderIndexes: orderIndexes,
                _feeReceiver: payable(BOB),
                _priceData: _priceUpdateCalldata,
                _publishTimeData: _publishTimeUpdateCalldata,
                _minPublishTime: _minPublishTime,
                _encodedVaas: keccak256("someEncodedVaas"),
                _isRevert: true
            });

            assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), 1, "User must have 1 market position, SHORT");
            _orderIndex = ForkEnv.limitTradeHandler.limitOrdersIndex(subAccount);

            vm.prank(ALICE);
            ForkEnv.limitTradeHandler.createOrder{ value: 0.1 ether }({
                _subAccountId: SUB_ACCOUNT_NO,
                _marketIndex: ARRAY_MARKET_INDEX[i],
                _sizeDelta: 1000 * 1e30,
                _triggerPrice: 0,
                _acceptablePrice: type(uint256).max,
                _triggerAboveThreshold: false,
                _executionFee: 0.1 ether,
                _reduceOnly: true,
                _tpToken: address(usdc_e)
            });

            orderIndexes[0] = _orderIndex;

            // Close Short Position
            vm.prank(0xB75ca1CC0B01B6519Bc879756eC431a95DC37882);
            ForkEnv.limitTradeHandler.executeOrders({
                _accounts: accounts,
                _subAccountIds: subAccountIds,
                _orderIndexes: orderIndexes,
                _feeReceiver: payable(BOB),
                _priceData: _priceUpdateCalldata,
                _publishTimeData: _publishTimeUpdateCalldata,
                _minPublishTime: _minPublishTime,
                _encodedVaas: keccak256("someEncodedVaas"),
                _isRevert: true
            });

            assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), 0, "User must have 0 market position after close, SHORT");
        }

    }
}