import { ethers } from "hardhat";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const orderExecutor = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> CrossMarginHandler: Set Order Executor...");
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  await (await crossMarginHandler.setOrderExecutor(orderExecutor, true)).wait();
  console.log("> CrossMarginHandler: Set Order Executor success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
