import { getConfig } from "../../utils/config";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import signers from "../../entities/signers";

const config = getConfig();

async function main() {
  const user = "0x05bDb067630e19e7e4aBF3436AF0e176Be573D32";
  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, signers.deployer(42161));
  const tx = await handler.setWhiteListExecutor(user, true, { gasLimit: 10000000 });
  await tx.wait(1);
  console.log(`Set whitelist to address: ${user}`);
}
