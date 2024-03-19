import { CrossMarginHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const handlers = [config.handlers.crossMargin, config.handlers.limitTrade, config.handlers.liquidity];
  const blastPts = "0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800";
  const blastPtsOperator = "0xC4D6713E4223B66708DD0167aAcf756D2D314192";

  for (const handler of handlers) {
    console.log(`[configs/GenericHandler] Set blastPtsOperator for ${handler}`);
    const h = CrossMarginHandler__factory.connect(handler, deployer);
    await ownerWrapper.authExec(
      h.address,
      h.interface.encodeFunctionData("setBlastPtsOperator", [blastPts, blastPtsOperator])
    );
  }
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
