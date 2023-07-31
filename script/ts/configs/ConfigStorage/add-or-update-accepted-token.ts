import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      tokenAddress: config.tokens.arb,
      config: {
        targetWeight: ethers.utils.parseEther("0"), // 0%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: false,
      },
    },
  ];

  console.log("> ConfigStorage: AddOrUpdateAcceptedToken...");
  const tx = await configStorage.addOrUpdateAcceptedToken(
    inputs.map((each) => each.tokenAddress),
    inputs.map((each) => each.config)
  );
  console.log(`Tx hash: ${tx.hash}`);
  await tx.wait();
  console.log("> ConfigStorage: AddOrUpdateAcceptedToken success!");
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
