import { ethers } from "hardhat";
import { LiquidityHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const minExecutionFee = ethers.utils.parseEther("0.00005");

  console.log("> LiquidityHandler: setMinExecutionFee...");
  const liquidityHandler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await (await liquidityHandler.setMinExecutionFee(minExecutionFee)).wait();
  console.log("> LiquidityHandler: setMinExecutionFee success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
