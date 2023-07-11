import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("AAPL"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("JPY"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAU"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("AMZN"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("TSLA"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("EUR"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAG"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("AUD"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("GBP"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("ADA"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("MATIC"),
    status: 2,
  },
  {
    assetId: ethers.utils.formatBytes32String("SUI"),
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
