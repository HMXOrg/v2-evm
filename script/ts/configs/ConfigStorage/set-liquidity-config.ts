import { Command } from "commander";
import { ConfigStorage__factory } from "../../../../typechain";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";

const liquidityConfig = {
  depositFeeRateBPS: 0, // 0%
  withdrawFeeRateBPS: 30, // 1%
  maxHLPUtilizationBPS: 8000, // 80%
  hlpTotalTokenWeight: 0, // DEFAULT
  hlpSafetyBufferBPS: 2000, // 20%
  taxFeeRateBPS: 100, // 1%
  flashLoanFeeRateBPS: 0,
  dynamicFeeEnabled: true,
  enabled: true,
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/ConfigStorage] Set Liquidity Config...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setLiquidityConfig", [liquidityConfig])
  );
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
