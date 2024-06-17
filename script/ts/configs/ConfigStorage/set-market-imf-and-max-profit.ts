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
      imfBps: 200,
      maxProfitRateBps: 200000,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Set Market IMF and Max Profits...");
  console.table(
    inputs.map((e) => {
      return {
        marketIndex: e.marketIndex,
        marketName: marketConfig.markets[e.marketIndex].name,
        maxLongPositionSize: e.imfBps,
        maxShortPositionSize: e.maxProfitRateBps,
      };
    })
  );
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setMarketIMFAndMaxProfit", [
      inputs.map((e) => e.marketIndex),
      inputs.map((e) => e.imfBps),
      inputs.map((e) => e.maxProfitRateBps),
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
