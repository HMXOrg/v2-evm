import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  {
    tokenAddress: config.tokens.usdc,
    config: {
      targetWeight: ethers.utils.parseEther("0.05"), // 5%
      bufferLiquidity: 0,
      maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
      accepted: true,
    },
  },
  {
    tokenAddress: config.tokens.usdt,
    config: {
      targetWeight: ethers.utils.parseEther("0"), // 0%
      bufferLiquidity: 0,
      maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
      accepted: false,
    },
  },
  {
    tokenAddress: config.tokens.dai,
    config: {
      targetWeight: ethers.utils.parseEther("0"), // 0%
      bufferLiquidity: 0,
      maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
      accepted: false,
    },
  },
  {
    tokenAddress: config.tokens.weth,
    config: {
      targetWeight: ethers.utils.parseEther("0"), // 0%
      bufferLiquidity: 0,
      maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
      accepted: false,
    },
  },
  {
    tokenAddress: config.tokens.wbtc,
    config: {
      targetWeight: ethers.utils.parseEther("0"), // 0%
      bufferLiquidity: 0,
      maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
      accepted: false,
    },
  },
  {
    tokenAddress: config.tokens.sglp,
    config: {
      targetWeight: ethers.utils.parseEther("0.95"), // 95%
      bufferLiquidity: 0,
      maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
      accepted: true,
    },
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: AddOrUpdateAcceptedToken...");
  await (
    await configStorage.addOrUpdateAcceptedToken(
      inputs.map((each) => each.tokenAddress),
      inputs.map((each) => each.config)
    )
  ).wait();
  console.log("> ConfigStorage: AddOrUpdateAcceptedToken success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
