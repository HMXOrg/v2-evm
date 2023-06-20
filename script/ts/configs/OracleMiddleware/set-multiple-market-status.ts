import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    status: 2,
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("> OracleMiddleware setMultipleMarketStatus...");
  await (
    await oracle.setMultipleMarketStatus(
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.status)
    )
  ).wait();
  console.log("> OracleMiddleware setMultipleMarketStatus success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
