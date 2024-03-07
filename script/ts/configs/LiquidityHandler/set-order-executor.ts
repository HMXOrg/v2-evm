import { ethers } from "hardhat";
import { LiquidityHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const orderExecutor = "0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E";

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);
  const deployer = (await ethers.getSigners())[0];
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/LiquidityHandler] Set Order Executor...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await ownerWrapper.authExec(
    handler.address,
    handler.interface.encodeFunctionData("setOrderExecutor", [orderExecutor, true])
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
