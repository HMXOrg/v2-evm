import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const assetId = ethers.utils.formatBytes32String("GLP");
const inverse = false;

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("GLP"),
    pythPriceId: ethers.utils.formatBytes32String("GLP"),
    inverse: false,
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("> PythAdapter Set Configs...");
  await (
    await pythAdapter.setConfigs(
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.pythPriceId),
      inputs.map((each) => each.inverse)
    )
  ).wait();
  console.log("> PythAdapter Set Configs success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
