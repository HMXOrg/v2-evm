import { ethers } from "hardhat";
import { LiquidityHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const orderExecutor = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> LiquidityHandler: Set Order Executor...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await (await handler.setOrderExecutor(orderExecutor, true)).wait();
  console.log("> LiquidityHandler: Set Order Executor success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
