import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    {
      fromSize: 0,
      toSize: ethers.utils.parseUnits("10000", 30),
      minProfitDuration: 60,
    },
    {
      fromSize: ethers.utils.parseUnits("10000", 30),
      toSize: ethers.utils.parseUnits("100000", 30),
      minProfitDuration: 180,
    },
    {
      fromSize: ethers.utils.parseUnits("100000", 30),
      toSize: ethers.utils.parseUnits("200000", 30),
      minProfitDuration: 300,
    },
    {
      fromSize: ethers.utils.parseUnits("200000", 30),
      toSize: ethers.constants.MaxUint256,
      minProfitDuration: 600,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Add Step Min Profit Duration...");
  console.table(
    inputs.map((each) => {
      return {
        ...each,
        fromSize: ethers.utils.formatUnits(each.fromSize, 30),
        toSize: ethers.utils.formatUnits(each.toSize, 30),
      };
    })
  );
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("addStepMinProfitDuration", [inputs])
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
