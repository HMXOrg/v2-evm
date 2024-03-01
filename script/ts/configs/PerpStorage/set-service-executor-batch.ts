import { ethers } from "hardhat";
import { PerpStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);

  const inputs = [
    {
      executorAddress: config.services.crossMargin,
      isServiceExecutor: true,
    },
    {
      executorAddress: config.services.trade,
      isServiceExecutor: true,
    },
    {
      executorAddress: config.helpers.trade,
      isServiceExecutor: true,
    },
    {
      executorAddress: config.services.liquidation,
      isServiceExecutor: true,
    },
  ];

  const deployer = (await ethers.getSigners())[0];
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);

  console.log("[configs/PerpStorage] Set Service Executors...");
  await ownerWrapper.authExec(
    perpStorage.address,
    perpStorage.interface.encodeFunctionData("setServiceExecutorBatch", [
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor),
    ])
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
