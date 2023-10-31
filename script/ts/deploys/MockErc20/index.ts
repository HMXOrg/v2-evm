import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { MockErc20__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying MockErc20 Contract`);
  const MockErc20 = new MockErc20__factory(deployer);
  const mockErc20 = await MockErc20.deploy("USDC", "USDC", 18);
  await mockErc20.deployed();
  console.log(`Deployed at: ${mockErc20.address}`);

  await tenderly.verify({
    address: mockErc20.address,
    name: "MockErc20",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
