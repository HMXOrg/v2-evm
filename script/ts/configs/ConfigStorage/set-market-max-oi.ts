import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";
import * as readlineSync from "readline-sync";

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

  const currentMarketConfigs = await configStorage.getMarketConfigs();

  console.log("[configs/ConfigStorage] Set Market Max OIs...");
  console.table(
    inputs.map((e) => {
      const existingMaxLongPositionSize = Number(
        ethers.utils.formatUnits(currentMarketConfigs[e.marketIndex].maxLongPositionSize, 30)
      );
      const existingMaxShortPositionSize = Number(
        ethers.utils.formatUnits(currentMarketConfigs[e.marketIndex].maxShortPositionSize, 30)
      );
      return {
        marketIndex: e.marketIndex,
        marketName: marketConfig.markets[e.marketIndex].name,
        existingMaxLongPositionSize,
        existingMaxShortPositionSize,
        maxLongPositionSize: e.maxLongPositionSize,
        maxShortPositionSize: e.maxShortPositionSize,
        diffLong: `${(e.maxLongPositionSize / existingMaxLongPositionSize - 1) * 100}%`,
        diffShort: `${(e.maxShortPositionSize / existingMaxShortPositionSize - 1) * 100}%`,
      };
    })
  );
  const confirm = readlineSync.question(`[configs/ConfigStorage] Confirm to update Max OIs? (y/n): `);
  switch (confirm) {
    case "y":
      break;
    case "n":
      console.log("[configs/ConfigStorage] Set Max OIs cancelled!");
      return;
    default:
      console.log("[configs/ConfigStorage] Invalid input!");
      return;
  }
  const tx = await configStorage.setMarketMaxOI(
    inputs.map((e) => e.marketIndex),
    inputs.map((e) => ethers.utils.parseUnits(e.maxLongPositionSize.toString(), 30)),
    inputs.map((e) => ethers.utils.parseUnits(e.maxShortPositionSize.toString(), 30))
  );
  console.log(`[config/ConfigStorage] Tx: ${tx.hash}`);
  await tx.wait();
  console.log("[config/ConfigStorage] Done");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
