import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    pythPriceId: ethers.utils.formatBytes32String("ETH"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    pythPriceId: ethers.utils.formatBytes32String("BTC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    pythPriceId: ethers.utils.formatBytes32String("USDC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    pythPriceId: ethers.utils.formatBytes32String("USDT"),
    inverse: false,
  },
];

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("[configs/PythAdapter] Setting configs...");
  await ownerWrapper.authExec(
    pythAdapter.address,
    pythAdapter.interface.encodeFunctionData("setConfigs", [
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.pythPriceId),
      inputs.map((each) => each.inverse),
    ])
  );
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
