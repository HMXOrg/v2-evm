import { ethers } from "hardhat";
import { LimitTradeHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const orderExecutor = "0x7FDD623c90a0097465170EdD352Be27A9f3ad817";

  const deployer = (await ethers.getSigners())[0];
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/LimitTradeHandler] Set order executor...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await ownerWrapper.authExec(
    limitTradeHandler.address,
    limitTradeHandler.interface.encodeFunctionData("setOrderExecutor", [orderExecutor, true])
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
