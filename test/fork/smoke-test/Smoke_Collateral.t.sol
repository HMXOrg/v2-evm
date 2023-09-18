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
    uint8 internal SUB_ACCOUNT_NO = 1;
    IERC20[] private collateralToken = new IERC20[](7);


    function setUp() public virtual override {
        super.setUp();
        collateralToken[0] = IERC20(address(ForkEnv.usdc_e));
        collateralToken[1] = IERC20(address(ForkEnv.weth));
        collateralToken[2] = IERC20(address(ForkEnv.wbtc));
        collateralToken[3] = IERC20(address(ForkEnv.usdt));
        collateralToken[4] = IERC20(address(ForkEnv.dai));
        collateralToken[5] = IERC20(address(ForkEnv.arb));
        collateralToken[6] = IERC20(address(ForkEnv.sglp));

    }

    function testCorrectness_SmokeTest_depositCollateral() external {
        _depositCollateral();
    }

    function testCorrectness_SmokeTest_withdrawCollateral() external {
        _depositCollateral();
        _withdrawCollateral();
    }


    function _depositCollateral() internal {
        address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
        for (uint8 i = 0; i < 7; i++) {
            uint8 tokenDecimal = collateralToken[i].decimals();
            // cannot deal sglp => transfer from whale instead
            if (i == 6) {
                vm.prank(ForkEnv.glpWhale);
                collateralToken[i].transfer(ALICE, 10 * (10 ** tokenDecimal));
            } else {
                deal(address(collateralToken[i]), ALICE, 10 * (10 ** tokenDecimal));
            }
            vm.startPrank(ALICE);
            collateralToken[i].approve(address(ForkEnv.crossMarginHandler), type(uint256).max);
            ForkEnv.crossMarginHandler.depositCollateral(
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
            "User must have 10 token in collateral"
            );
        }
    }

    function _withdrawCollateral() internal {
        uint256 minExecutionFee = ForkEnv.crossMarginHandler.minExecutionOrderFee();
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
            uint256 _latestOrderIndex = ForkEnv.crossMarginHandler.createWithdrawCollateralOrder{ value: minExecutionFee }(
                SUB_ACCOUNT_NO,
                address(collateralToken[i]),
                10 * (10 ** tokenDecimal),
                minExecutionFee,
                false
            );

        
            vm.prank(ForkEnv.liquidityOrderExecutor);
            ForkEnv.crossMarginHandler.executeOrder(
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
            "User must have 10 token in their wallet"
            );
        }
    }

}
