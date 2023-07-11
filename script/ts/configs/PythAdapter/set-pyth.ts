import { PythAdapter__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";

async function main() {
  const NEW_PYTH = "";

  const deployer = signers.deployer(42161);
  const config = loadConfig(42161);

  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);
  console.log("[PythAdapter] Set Pyth...");
  const tx = await pythAdapter.setPyth(NEW_PYTH);
  console.log(`[PythAdapter] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[PythAdapter] Finished");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
