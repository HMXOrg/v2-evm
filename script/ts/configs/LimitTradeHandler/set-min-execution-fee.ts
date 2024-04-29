import { ethers } from "hardhat";
import { LimitTradeHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const minExecutionFee = ethers.utils.parseEther("0.00005");

  console.log("> LimitTradeHandler: setMinExecutionFee...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await (await limitTradeHandler.setMinExecutionFee(minExecutionFee)).wait();
  console.log("> LimitTradeHandler: setMinExecutionFee success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
