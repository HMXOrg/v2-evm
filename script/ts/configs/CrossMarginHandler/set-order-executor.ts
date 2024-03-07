import { ethers } from "hardhat";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const orderExecutor = "0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E";

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);
  const deployer = (await ethers.getSigners())[0];
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/CrossMarginHandler] Set Order Executor...");
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  await ownerWrapper.authExec(
    crossMarginHandler.address,
    crossMarginHandler.interface.encodeFunctionData("setOrderExecutor", [orderExecutor, true])
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
