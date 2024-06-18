import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    {
      executorAddress: "0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872", // Deployer
      isServiceExecutor: true,
    },
    {
      executorAddress: "0x60F80329d206A432D8aE3E4b34F505920cb17CdE", // J.Xina Signer
      isServiceExecutor: true,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Set Config Executors...");
  console.table(inputs);
  for (let i = 0; i < inputs.length; i++) {
    await ownerWrapper.authExec(
      configStorage.address,
      configStorage.interface.encodeFunctionData("setConfigExecutor", [
        inputs[i].executorAddress,
        inputs[i].isServiceExecutor,
      ])
    );
  }
  console.log("[config/ConfigStorage] Done");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
