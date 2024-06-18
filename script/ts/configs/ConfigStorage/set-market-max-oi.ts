import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);

  const inputs = [
    {
      marketIndex: 0,
      maxLongPositionSize: 1000000,
      maxShortPositionSize: 1000000,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Set Market Max OIs...");
  console.table(
    inputs.map((e) => {
      return {
        marketIndex: e.marketIndex,
        marketName: marketConfig.markets[e.marketIndex].name,
        maxLongPositionSize: e.maxLongPositionSize,
        maxShortPositionSize: e.maxShortPositionSize,
      };
    })
  );
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setMarketMaxOI", [
      inputs.map((e) => e.marketIndex),
      inputs.map((e) => ethers.utils.parseUnits(e.maxLongPositionSize.toString(), 30)),
      inputs.map((e) => ethers.utils.parseUnits(e.maxShortPositionSize.toString(), 30)),
    ])
  );
  console.log("[config/ConfigStorage] Done");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
