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

  const orderExecutor = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
  const isAllow = true;

  console.log("[config/Ext01Handler] Ext01Handler setOrderExecutor...");
  const owner = await ext01Handler.owner();
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      ext01Handler.address,
      0,
      ext01Handler.interface.encodeFunctionData("setOrderExecutor", [orderExecutor, isAllow])
    );
    console.log(`[config/Ext01Handler] Proposed ${tx} to setOrderExecutor`);
  } else {
    const tx = await ext01Handler.setOrderExecutor(orderExecutor, isAllow);
    console.log(`[config/Ext01Handler] setOrderExecutor Done at ${tx.hash}`);
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
