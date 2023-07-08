import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { EcoPyth2__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying EcoPyth2 Contract`);
  const Ecopyth2 = new EcoPyth2__factory(deployer);
  const ecoPyth2 = await Ecopyth2.deploy();
  await ecoPyth2.deployed();
  console.log(`Deployed at: ${ecoPyth2.address}`);

  config.oracles.ecoPyth2 = ecoPyth2.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: ecoPyth2.address,
    name: "EcoPyth2",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
