import { LimitTradeHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import signers from "../../entities/signers";
import { ethers } from "ethers";

async function main() {
  const config = loadConfig(42161);
  const deployer = signers.deployer(42161);
  const ownerWrapper = new OwnerWrapper(42161, deployer);
  const minExecutionFee = ethers.utils.parseEther("0.042");

  console.log("> LimitTradeHandler: setMinExecutionFee...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await ownerWrapper.authExec(
    limitTradeHandler.address,
    limitTradeHandler.interface.encodeFunctionData("setMinExecutionFee", [minExecutionFee])
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
