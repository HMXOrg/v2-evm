import { ethers } from "hardhat";
import { LiquidityHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const orderExecutor = "0x0578C797798Ae89b688Cd5676348344d7d0EC35E";

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
