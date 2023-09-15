// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

import "forge-std/console.sol";

contract Smoke_Collateral is Smoke_Base {

    CrossMarginHandler crossMarginHandler = CrossMarginHandler(payable(0xB189532c581afB4Fbe69aF6dC3CD36769525d446));
    uint8 internal SUB_ACCOUNT_NO = 1;
    IERC20[] private collateralToken = new IERC20[](7);


    function setUp() public virtual override {
        super.setUp();
        // "usdc": "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8",
        // "weth": "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
        // "wbtc": "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f",
        // "usdt": "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",
        // "dai": "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",
        // "arb": "0x912CE59144191C1204E64559FE8253a0e49E6548",
        // "sglp": "0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf",
        collateralToken[0] = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
        collateralToken[1] = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        collateralToken[2] = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
        collateralToken[3] = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
        collateralToken[4] = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        collateralToken[5] = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
        collateralToken[6] = IERC20(0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf);

    }

    function test_deposit_collateral_fork() external {
        _depositCollateral();
    }

    function test_withdraw_collateral_fork() external {
        _depositCollateral();
        _withdrawCollateral();
    }


    function _depositCollateral() internal {
        address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
        for (uint8 i = 0; i < 7; i++) {
            uint8 tokenDecimal = collateralToken[i].decimals();
            // cannot deal sglp => transfer from whale instead
            if (i == 6) {
                vm.prank(0x97bb6679ae5a6c66fFb105bA427B07E2F7fB561e);
                collateralToken[i].transfer(ALICE, 10 * (10 ** tokenDecimal));
            } else {
                deal(address(collateralToken[i]), ALICE, 10 * (10 ** tokenDecimal));
            }
            vm.startPrank(ALICE);
            collateralToken[i].approve(address(crossMarginHandler), type(uint256).max);
            crossMarginHandler.depositCollateral(
                SUB_ACCOUNT_NO,
                address(collateralToken[i]), 
                10 * (10 ** tokenDecimal), 
                false
            );
            vm.stopPrank();
            assertApproxEqRel(
            10 * (10 ** tokenDecimal),
            vaultStorage.traderBalances(subAccount, address(collateralToken[i])),
            0.01 ether,
            "User Deposit Collateral"
            );
        }
    }

    function _withdrawCollateral() internal {
        uint256 minExecutionFee = crossMarginHandler.minExecutionOrderFee();
        address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
        IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
        (
        uint256 _minPublishTime,
        bytes32[] memory _priceUpdateCalldata,
        bytes32[] memory _publishTimeUpdateCalldata
        ) = ecoPythBuilder.build(data);
        for (uint8 i = 0; i < 7; i++) {
            uint8 tokenDecimal = collateralToken[i].decimals();
            deal(ALICE, minExecutionFee);
            vm.prank(ALICE);
            uint256 _latestOrderIndex = crossMarginHandler.createWithdrawCollateralOrder{ value: minExecutionFee }(
                SUB_ACCOUNT_NO,
                address(collateralToken[i]),
                10 * (10 ** tokenDecimal),
                minExecutionFee,
                false
            );

        
            vm.prank(0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E);
            crossMarginHandler.executeOrder(
                _latestOrderIndex, 
                payable(ALICE), 
                _priceUpdateCalldata, 
                _publishTimeUpdateCalldata, 
                _minPublishTime, 
                keccak256("someEncodedVaas")
            );
            assertApproxEqRel(
            10 * (10 ** tokenDecimal),
            collateralToken[i].balanceOf(ALICE),
            0.01 ether,
            "User Withdraw Collateral"
            );
        }
    }

}
