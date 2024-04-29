import { MockChronicleOraclePriceAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const mockChronicleOraclePriceAdapter = MockChronicleOraclePriceAdapter__factory.connect(
    config.oracles.priceAdapters.wusdm,
    deployer
  );

  console.log("[configs/MockChronicleOraclePriceAdapter] Set current price...");
  await mockChronicleOraclePriceAdapter.setCurrentPrice(ethers.utils.parseEther("1"));
  console.log("[configs/MockChronicleOraclePriceAdapter] Set current price success!");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
