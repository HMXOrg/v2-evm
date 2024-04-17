import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { MockErc20__factory, MockWNative__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying MockWNative Contract`);
  const MockWNative = new MockWNative__factory(deployer);
  const mockWNative = await MockWNative.deploy();
  await mockWNative.deployed();
  console.log(`Deployed at: ${mockWNative.address}`);

  config.tokens.weth = mockWNative.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: mockWNative.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
