import { ethers } from "hardhat";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const minExecutionFee = ethers.utils.parseEther("0.00005");

  console.log("> CrossMarginHandler: setMinExecutionFee...");
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  await (await crossMarginHandler.setMinExecutionFee(minExecutionFee)).wait();
  console.log("> CrossMarginHandler: setMinExecutionFee success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});