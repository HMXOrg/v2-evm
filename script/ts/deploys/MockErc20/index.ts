import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { MockErc20__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying MockErc20 Contract`);
  const name = "DAI";
  const symbol = "DAI";
  const decimals = 18;
  const MockErc20 = new MockErc20__factory(deployer);
  const mockErc20 = await MockErc20.deploy(name, symbol, decimals);
  await mockErc20.deployed();
  console.log(`Deployed at: ${mockErc20.address}`);
  config.tokens.dai = mockErc20.address;

  writeConfigFile(config);

  await run("verify:verify", {
    address: mockErc20.address,
    constructorArguments: [name, symbol, decimals],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
