import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { MockWNative__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying MockWNative Contract`);
  const MockWNative = new MockWNative__factory(deployer);
  const mockWNative = await MockWNative.deploy();
  await mockWNative.deployed();
  console.log(`Deployed at: ${mockWNative.address}`);

  await tenderly.verify({
    address: mockWNative.address,
    name: "MockWNative",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
