import { getChainId } from "hardhat";
import { LiquidityHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  console.log("> LiquidityHandler: Set HLP Staking...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await (await handler.setHlpStaking(config.staking.hlp)).wait();
  console.log("> LiquidityHandler: Set HLP Staking success!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
