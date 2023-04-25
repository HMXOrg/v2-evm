import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { CrossMarginHandler__factory, ERC20__factory, LiquidityHandler__factory, PLPv2__factory } from "../typechain";
import { getConfig } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const liquidityHandler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  const plp = PLPv2__factory.connect(config.tokens.hlp, deployer);
  const allowance = await plp.allowance(deployer.address, liquidityHandler.address);
  if (allowance.eq(0)) await (await plp.approve(liquidityHandler.address, ethers.constants.MaxUint256)).wait();

  const executionFee = await liquidityHandler.executionOrderFee();
  console.log(`Execution Fee: ${executionFee}`);
  console.log(`Creating Remove Liquidity Order...`);
  await (
    await liquidityHandler.createRemoveLiquidityOrder(
      config.tokens.usdc,
      ethers.utils.parseUnits("400", 18),
      0,
      executionFee,
      false,
      { value: executionFee, gasLimit: 20000000 }
    )
  ).wait();
  console.log("Create Remove Liquidity Order Success!");
};

export default func;
func.tags = ["RemoveLiquidity"];
