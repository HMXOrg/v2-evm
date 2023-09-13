import { Ext01Handler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";
import { compareAddress } from "../../utils/address";
import { ethers } from "ethers";

// OrderType 1 = Create switch collateral order
const SWITCH_COLLATERAL_ORDER_TYPE = 1;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const ext01Handler = Ext01Handler__factory.connect(config.handlers.ext01, deployer);

  const orderType = SWITCH_COLLATERAL_ORDER_TYPE;
  const minExecutionFee = ethers.utils.parseEther("0.0003");

  console.log("[config/Ext01Handler] Ext01Handler setMinExecutionFee...");
  const owner = await ext01Handler.owner();
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      ext01Handler.address,
      0,
      ext01Handler.interface.encodeFunctionData("setMinExecutionFee", [orderType, minExecutionFee])
    );
    console.log(`[config/Ext01Handler] Proposed ${tx} to setMinExecutionFee`);
  } else {
    const tx = await ext01Handler.setMinExecutionFee(orderType, minExecutionFee);
    console.log(`[config/Ext01Handler] setMinExecutionFee Done at ${tx.hash}`);
    await tx.wait();
  }
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
