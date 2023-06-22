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
    assetId: ethers.utils.formatBytes32String("ETH"),
    pythPriceId: ethers.utils.formatBytes32String("ETH"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    pythPriceId: ethers.utils.formatBytes32String("BTC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    pythPriceId: ethers.utils.formatBytes32String("USDC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    pythPriceId: ethers.utils.formatBytes32String("USDT"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("DAI"),
    pythPriceId: ethers.utils.formatBytes32String("DAI"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("AAPL"),
    pythPriceId: ethers.utils.formatBytes32String("AAPL"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("JPY"),
    pythPriceId: ethers.utils.formatBytes32String("JPY"),
    inverse: true,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAU"),
    pythPriceId: ethers.utils.formatBytes32String("XAU"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("AMZN"),
    pythPriceId: ethers.utils.formatBytes32String("AMZN"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("MSFT"),
    pythPriceId: ethers.utils.formatBytes32String("MSFT"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("TSLA"),
    pythPriceId: ethers.utils.formatBytes32String("TSLA"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("EUR"),
    pythPriceId: ethers.utils.formatBytes32String("EUR"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAG"),
    pythPriceId: ethers.utils.formatBytes32String("XAG"),
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
